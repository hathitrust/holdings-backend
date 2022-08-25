# A fully automated scrubber would:
# Check member directories for new member-submitted files
# Compare remote files to processed files
# Copy new files to work directory
# Validate and scrub files into loadable format
# Load files into db
# Upload report to member dir
# ... should be able to do this for any number of members/files, at a whim or by cron,
# ideally using a queue or pool of workers.

require "data_sources/ht_organizations"
require "data_sources/directory_locator"
require "loader/file_loader"
require "loader/holding_loader"
require "scrub/autoscrub"
require "scrub/chunker"
require "utils/file_transfer"
require "fileutils"
require "loader/holding_loader"

# Example:
# runner = Scrub::ScrubRunner.new
# runner.run_all_members
# runner.run_some_members(["umich", ..., "harvard"])
# runner.run_one_member("umich")

module Scrub
  # Scrubs and loads any new member-uploaded files.
  class ScrubRunner
    def initialize
      if Settings.local_member_dir.nil?
        raise "Need Settings.local_member_dir to be set"
      end
      if Settings.remote_member_dir.nil?
        raise "Need Settings.remote_member_dir to be set"
      end
      @ft = Utils::FileTransfer.new
    end

    def run_all_members
      puts "Run all members."
      @members = DataSources::HTOrganizations.new.members.keys.sort
      run_some_members(@members)
    end

    def run_some_members(members)
      puts "Run members: #{members}."
      members.each do |member|
        run_one_member(member)
      end
    end

    def run_one_member(member)
      puts "Running member #{member}."
      new_files = check_new_files(member)
      puts "Found #{new_files.size} new files: #{new_files.join(", ")}."
      new_files.each do |new_file|
        run_file(member, file)
      end
    end

    # This should ideally spin off another (set of?) worker thread(s).
    def run_file(member, file)
      puts "running file #{file} for member #{member}"
      downloaded_file = download_to_work_dir(member, file)
      scrubber = Scrub::AutoScrub.new(downloaded_file)
      scrubber.run
      scrubber.out_files.each do |scrubber_out_file|
        puts "Prepare loading of #{scrubber_out_file}"
        system "cat \"#{scrubber_out_file}\""
        chunker = Scrub::Chunker.new(glob: scrubber_out_file, chunk_count: 4)
        chunker.run
        chunker.chunks.each do |chunk|
          puts "load chunk #{chunk}"
          system("cat \"#{chunk}\"")
          batch_loader = Loader::HoldingLoader.for(".ndj")
          Loader::FileLoader.new(batch_loader: batch_loader).load(chunk)
          puts "chunk loaded!"
        end
        chunker.cleanup! # maybe not yet?
        upload_to_member(member, scrubber_out_file)
      end
    end

    # Check member-uploaded files for any not previously seen files
    def check_new_files(member)
      puts "check new files for member #{member}"
      remote_dir = DataSources::DirectoryLocator.new(
        Settings.remote_member_dir,
        member
      ).holdings_current
      remote_files = @ft.lsjson(remote_dir).map { |f| f["Name"] }
      old_files = check_old_files(member)
      # Return new (as in previously not processed) files
      new_files = remote_files - old_files
      puts "found #{new_files.size} new file(s)"
      new_files
    end

    # Check the member scrub_dir for previously scrubbed files.
    def check_old_files(member)
      puts "check old files for #{member}"
      local_dir = DataSources::DirectoryLocator.new(
        Settings.local_member_dir,
        member
      ).holdings_current
      @ft.lsjson(local_dir).map { |f| f["Name"] }
    end

    def download_to_work_dir(member, file)
      puts "download remote file #{file} to work dir for #{member}"
      work_dir = DataSources::DirectoryLocator.new(
        Settings.local_member_dir,
        member
      ).holdings_current
      @ft.download(file, work_dir)
      # Return the path to the downloaded file
      File.join(work_dir, File.split(file).last)
    end

    def upload_to_member(member, file)
      puts "upload local file #{file} to remote dir for #{member}"
      # todo: something something rclone, upload scrub report to dropbox
    end

    def move_to_scrubbed_dir(member, file)
      scrubbed_dir = "#{Settings.local_member_dir}/#{member}"
      puts "move #{file} to #{scrubbed_dir}"
      FileUtils.mv(file, scrubbed_dir)
    end
  end
end
