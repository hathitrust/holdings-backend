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
require "utils/slack_notifier"

# Example:
# runner = Scrub::ScrubRunner.new(ORG)
# runner.run

module Scrub
  # Scrubs and loads any new org-uploaded files.
  class ScrubRunner
    attr_reader :force, :file_transfer, :organization, :force_holding_loader_cleanup_test, :type_check

    def initialize(organization, options = {})
      @organization = organization
      # @force: force loading a file even if it exceeds diff limit
      @force = options.fetch("force", false)
      # @force_holding_loader_cleanup_test: only set to true in testing.
      @force_holding_loader_cleanup_test = options.fetch("force_holding_loader_cleanup_test", false)
      @type_check = options.fetch("type_check", true)
      # If type_check is false, backup and delete any types not represented in the new files.
      # This should be set to true when loading a format change (spm/mpm/ser -> mon/ser)
      # but should be set to false if reloading a failed file when others succeeded.
      @allow_delete = options.fetch("allow_delete", false)
      @file_transfer = Utils::FileTransfer.new
      validate
    end

    # Entrypoint from `phctl scrub` command. Scrub and load.
    def run
      Services.logger.info "Running org #{organization}."
      new_files = check_new_files
      deleted_types = []
      Services.logger.info "Found #{new_files.size} new files: #{new_files.join(", ")}."
      type_checker = Scrub::TypeChecker.new(
        organization: organization,
        new_types: new_types(new_files)
      )
      if type_check
        # Only allow loading of previously seen types, or when nothing is currently loaded
        begin
          type_checker.validate
        rescue Scrub::TypeCheckError => err
          Utils::SlackNotifier.post(
            "Holdings scrub rejected for *#{organization}* — #{err.message}"
          )
          raise
        end
      elsif @allow_delete
        deleted_types = type_checker.deleted_types
      end

      new_files.each do |new_file|
        run_file(new_file)
      end
      deleted_types.each do |deleted_type|
        delete_type(deleted_type)
      end
    end

    # From `phctl scrub_file` command -- download and scrub without loading.
    def scrub_file(filename)
      Dir.mktmpdir do |tmp_dir|
        remote_file = File.join(remote_dir, filename)
        file_transfer.download(remote_file, tmp_dir)
        downloaded_file = File.join(tmp_dir, File.basename(filename))
        scrubber = Scrub::AutoScrub.new(downloaded_file, force)
        scrubber.run
        scrubber.out_files
      end
    end

    def delete_type(type)
      Services.logger.info "Running deletion job for type #{type}"

      # Create a backup file and mark old records for deletion
      pre_load_backup = Scrub::PreLoadBackup.new(
        organization: organization,
        mono_multi_serial: type
      )
      pre_load_backup.write_backup_file
      pre_load_backup.mark_for_deletion

      cleanup_data = {
        "organization" => organization,
        "mono_multi_serial" => type
      }
      batch = Sidekiq::Batch.new
      batch.description = "Holdings deletion for #{organization}'s deleted #{type}"
      batch.on(:success, Loader::HoldingLoader::DeletionCleanup, cleanup_data)

      batch.jobs do
        Services.logger.info "Queueing nonexistent chunk"
        Jobs::Load::HoldingsDeletion.perform_async
      end
      # In test, where sidekiq is not running, we do this
      # instead of relying on the on_success-hook.
      if force_holding_loader_cleanup_test
        Services.logger.info "Forcing Loader::HoldingLoader::DeletionCleanup, TEST ONLY!"
        Loader::HoldingLoader::DeletionCleanup.new.on_success(:success, cleanup_data)
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

      # MalformedFileError message already contains the filename and diff details; other errors need err.class for triage.
      # TODO: Consider adding err.class to MalformedFileError's Slack message for consistency with other error types.
      slack_msg = if err.is_a?(MalformedFileError)
        "Holdings scrub rejected for *#{organization}* — #{err.message}"
      else
        "Holdings scrub failed for *#{organization}* — " \
        "`#{member_submitted_file["Name"]}` (#{err.class}): #{err.message}"
      end
      Utils::SlackNotifier.post(slack_msg)

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
        # Ignore logs we upload
        next if f["Name"].end_with?(".log")
        # Ignore Alma XML, see `AlmaHoldings` class
        next if f["Name"].end_with?(".xml")
        next if f["Name"].end_with?(".tar.gz")
        # Ignore subdirectories. We may stash e.g., XML originals in a subdirectory
        next if f["IsDir"]
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

    # Get the types of the files we are loading.
    def new_types(files)
      files.map { |file| Scrub::MemberHoldingFile.new(file["Path"]).item_type }.to_set
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
