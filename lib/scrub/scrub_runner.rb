# A fully automated scrubber would:
# Check org directories for new org-submitted files
# Compare remote files to processed files
# Copy new files to work directory
# Validate and scrub files into loadable format
# Load files into db
# Upload report to org dir
# ... should be able to do this for any number of orgs/files, at a whim or by cron,
# ideally using a queue or pool of workers.

require "data_sources/directory_locator"
require "data_sources/ht_organizations"
require "fileutils"
require "loader/file_loader"
require "loader/holding_loader"
require "scrub/autoscrub"
require "scrub/chunker"
require "scrub/malformed_file_error"
require "scrub/member_holding_file"
require "scrub/pre_load_backup"
require "scrub/record_counter"
require "scrub/type_checker"
require "sidekiq_jobs"
require "sidekiq/batch"
require "utils/file_transfer"
require "utils/line_counter"

# Example:
# runner = Scrub::ScrubRunner.new(ORG)
# runner.run

module Scrub
  # Scrubs and loads any new org-uploaded files.
  class ScrubRunner
    attr_reader :force, :file_transfer, :organization, :force_holding_loader_cleanup_test

    def initialize(organization, options = {})
      @organization = organization
      # @force: force loading a file even if it exceeds diff limit
      @force = options["force"] || false
      # @force_holding_loader_cleanup_test: only set to true in testing.
      @force_holding_loader_cleanup_test = options["force_holding_loader_cleanup_test"] || false
      @file_transfer = Utils::FileTransfer.new
      validate
    end

    def run
      Services.logger.info "Running org #{organization}."
      new_files = check_new_files
      Services.logger.info "Found #{new_files.size} new files: #{new_files.join(", ")}."
      check_new_types(new_files)

      new_files.each do |new_file|
        run_file(new_file)
      end
    end

    def run_file(member_submitted_file)
      Services.logger.info "Running member_submitted_file #{member_submitted_file}"
      downloaded_file = download_to_work_dir(member_submitted_file)
      scrubber = Scrub::AutoScrub.new(downloaded_file, force)
      scrubber.run

      record_counter = Scrub::RecordCounter.new(organization, scrubber.item_type)
      unless record_counter.acceptable_diff? || force
        raise MalformedFileError, [
          "Diff too big for #{organization} when scrubbing #{member_submitted_file["Name"]}.",
          record_counter.message.join("\n"),
          "This file will not be loaded."
        ].join("\n")
        # Run again with --force to load anyways.
      end

      scrubber.out_files.each do |scrubber_out_file|
        chunk_and_load(
          member_submitted_file: member_submitted_file,
          scrubber: scrubber,
          scrubber_out_file: scrubber_out_file
        )
      end
    rescue => err
      Services.logger.error err
      Services.scrub_logger.error "Unexpected error. Please contact HathiTrust."
      Services.scrub_logger.error err.message

      # Do things Loader::HoldingLoader::Cleanup normally does
      FileUtils.rm(downloaded_file)
      Utils::FileTransfer.new.upload(scrubber.logger_path, remote_dir)
    end

    def chunk_and_load(member_submitted_file:, scrubber:, scrubber_out_file:)
      Services.logger.info "Ready to split #{scrubber_out_file} into chunks"
      chunker = Scrub::Chunker.new(
        scrubber_out_file,
        chunk_count: Settings.scrub_chunk_count,
        out_ext: "ndj"
      )
      chunker.run

      # Create a backup file and mark old records for deletion
      pre_load_backup = Scrub::PreLoadBackup.new(
        organization: organization,
        mono_multi_serial: scrubber.item_type
      )
      pre_load_backup.write_backup_file
      pre_load_backup.mark_for_deletion

      # Prepare data for Loader::HoldingLoader::Cleanup's on-success hook
      cleanup_data = {
        "raw_file" => member_submitted_file["Name"],
        "tmp_chunk_dir" => chunker.tmp_chunk_dir,
        "organization" => organization,
        "scrub_log" => scrubber.logger_path,
        "remote_dir" => remote_dir,
        "loaded_file" => scrubber_out_file,
        "loaded_dir" => scrubber.output_struct.member_loaded.path,
        "mono_multi_serial" => scrubber.item_type
      }
      batch_jobs(
        chunker: chunker,
        cleanup_data: cleanup_data,
        scrubber_out_file: scrubber_out_file
      )
    end

    def batch_jobs(chunker:, cleanup_data:, scrubber_out_file:)
      batch = Sidekiq::Batch.new
      batch.description = "Holdings load for #{organization}'s #{scrubber_out_file}"
      batch.on(:success, Loader::HoldingLoader::Cleanup, cleanup_data)

      batch.jobs do
        chunker.chunks.each do |chunk|
          Services.logger.info "Queueing chunk #{chunk}"
          Jobs::Load::Holdings.perform_async(chunk)
        end
      end
      # In test, where sidekiq is not running, we do this
      # instead of relying on the on_success-hook.
      if force_holding_loader_cleanup_test
        Services.logger.info "Forcing Loader::HoldingLoader::Cleanup, TEST ONLY!"
        Loader::HoldingLoader::Cleanup.new.on_success(:success, cleanup_data)
      end
    end

    # Check org-uploaded files for any not previously seen files
    def check_new_files
      # Return new (as in not in old) files
      remote_files = file_transfer.lsjson(remote_dir)
      old_files = check_old_files
      # Include in new_files only those remote_files whose name is not in old_files.
      new_files = []
      remote_files.each do |f|
        # Possibly filtering other files here.
        next if f["Name"].end_with?(".log")
        if old_files.select { |oldf| f["Name"] == oldf["Name"] }.empty?
          new_files << f
        end
      end

      new_files
    end

    # Check the org scrub_dir for previously scrubbed files.
    def check_old_files
      DataSources::DirectoryLocator.for(:local, organization).ensure!
      file_transfer.lsjson(local_dir)
    end

    # "file" here is annoyingly a RClone.lsjson output hash
    # with format {"Path": x, "Name": y, ...}
    def download_to_work_dir(file)
      remote_file = File.join(remote_dir, file["Path"])
      file_transfer.download(remote_file, local_dir)

      # Return the path to the downloaded file
      File.join(local_dir, File.split(remote_file).last)
    end

    private

    def check_new_types(files)
      # Get the types of the files we are loading.
      types = Set.new
      files.each do |f|
        member_holding_file = Scrub::MemberHoldingFile.new(f["Path"])
        types << member_holding_file.item_type
      end

      # Alert & abort if the types are not a subset of types we have loaded for organization before.
      Scrub::TypeChecker.new(organization: organization, new_types: types).validate
    end

    def remote_dir
      DataSources::DirectoryLocator.for(:remote, organization).holdings_current
    end

    def local_dir
      DataSources::DirectoryLocator.for(:local, organization).holdings_current
    end

    def validate
      if Settings.local_member_data.nil?
        raise "Need Settings.local_member_data to be set"
      end
      if Settings.remote_member_data.nil?
        raise "Need Settings.remote_member_data to be set"
      end
      if Settings.scrub_chunk_count.nil?
        raise "Need Settings.scrub_chunk_count to be set"
      end
      if Settings.scrub_line_count_diff_max.nil?
        raise "Need Settings.scrub_line_count_diff_max to be set"
      end
      if organization.nil?
        raise "Need @organization to be set"
      end
      unless [true, false].include?(force)
        raise "Need @force to be true/false"
      end
      unless [true, false].include?(force_holding_loader_cleanup_test)
        raise "Need @force_holding_loader_cleanup_test to be true/false"
      end
    end
  end
end
