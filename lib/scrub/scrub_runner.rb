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
require "utils/file_transfer"

# Example:
# runner = Scrub::ScrubRunner.new(ORG)
# runner.run

module Scrub
  # Scrubs and loads any new org-uploaded files.
  class ScrubRunner
    def initialize(organization)
      @organization = organization
      @ft = Utils::FileTransfer.new
      validate
    end

    def validate
      if Settings.local_member_data.nil?
        raise "Need Settings.local_member_data to be set"
      end
      if Settings.remote_member_data.nil?
        raise "Need Settings.remote_member_data to be set"
      end
      if @organization.nil?
        raise "Need @organization to be set"
      end
    end

    def run
      Services.logger.info "Running org #{@organization}."
      new_files = check_new_files
      Services.logger.info "Found #{new_files.size} new files: #{new_files.join(", ")}."
      new_files.each do |new_file|
        run_file(new_file)
      end
    end

    def run_file(file)
      Services.logger.info "Running file #{file}"
      downloaded_file = download_to_work_dir(file)
      scrubber = Scrub::AutoScrub.new(downloaded_file)
      scrubber.run
      scrubber.out_files.each do |scrubber_out_file|
        Services.logger.info "Ready to split #{scrubber_out_file} into chunks"
        chunker = Scrub::Chunker.new(scrubber_out_file, chunk_count: 4, out_ext: "ndj")
        chunker.run
        chunker.chunks.each do |chunk|
          Services.logger.info "Load chunk #{chunk}"
          Loader::FileLoader.new(batch_loader: Loader::HoldingLoader.for(chunk)).load(chunk)
        end
        # do when chunks are done, except we don;t know how really
        chunker.cleanup!
        upload_to_member(scrubber.logger_path)
      end
    rescue
      # If the scrub failed, remove the file from local storage, that we may try again.
      FileUtils.rm(downloaded_file)
      raise "Scrub failed, removing downloaded file #{downloaded_file}"
    end

    # Check org-uploaded files for any not previously seen files
    def check_new_files
      # Return new (as in not in old) files
      remote_files = @ft.lsjson(remote_dir)
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
      DataSources::DirectoryLocator.for(:local, @organization).ensure!
      @ft.lsjson(local_dir)
    end

    # "file" here is annoyingly a RClone.lsjson output hash
    # with format {"Path": x, "Name": y, ...}
    def download_to_work_dir(file)
      remote_file = File.join(remote_dir, file["Path"])
      @ft.download(remote_file, local_dir)

      # Return the path to the downloaded file
      File.join(local_dir, File.split(remote_file).last)
    end

    def upload_to_member(file)
      Services.logger.info "upload local file #{file} to remote dir"
      @ft.upload(file, remote_dir)
    end

    def remote_dir
      DataSources::DirectoryLocator.for(:remote, @organization).holdings_current
    end

    def local_dir
      DataSources::DirectoryLocator.for(:local, @organization).holdings_current
    end
  end
end
