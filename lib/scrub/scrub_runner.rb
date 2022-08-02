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
require "loader/file_loader"
require "loader/holding_loader"
require "scrub/autoscrub"
require "fileutils"

# Example:
# runner = Scrub::ScrubRunner.new
# runner.run_all_members
# runner.run_some_members(["umich", ..., "harvard"])
# runner.run_one_member("umich")

module Scrub
  # Scrubs and loads any new member-uploaded files.
  class ScrubRunner
    def initialize
      @members = DataSources::HTOrganizations.organizations
      if Settings.scrubbed_files_dir.nil?
        raise "Need Settings.scrubbed_files_dir to be set"
      end
    end
    # see lib/reports/etas_organization_overlap_report.rb for rclone stuff,
    # should be broken out into its own class?

    def run_all_members
      puts "Run all members."
      run_some_members(@members)
    end

    def run_some_members(members)
      puts "Run members: #{members.join(", ")}."
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
      download_to_work_dir(member, new_file)
      scrubber = Scrub::Autoscrub.new(new_file)
      scrubber.run
      # figure out the output files that was just generated
      # todo: implement scrubber.reports and/or do it with Scrub::ScrubOutputStructure
      upload_to_member(member, scrubber.reports.latest)
      holding_loader = Loader::HoldingLoader.for(scrubber.output.latest)
      Loader::FileLoader.new(holding_loader).load(scrubber.output.latest)
    end

    # Check member-uploaded files for any not previously seen files
    def check_new_files(member)
      puts "check new files for member #{member}"
      remote_files = [] # todo: something something rclone
      old_files = check_old_files(member)
      # Return new (as in previously not processed) files
      new_files = remote_files - old_files
      puts "found #{new_files.size} new files"
      new_files
    end

    # Check the member scrub_dir for previously scrubbed files.
    def check_old_files(member)
      puts "check old files for #{member}"
      scrubbed_dir = "#{Settings.scrubbed_files_dir}/#{member}"
      unless Dir.exist?(scrubbed_dir)
        Dir.mkdir(scrubbed_dir)
      end
      Dir.new(scrubbed_dir).to_a
    end

    def download_to_work_dir(member, file)
      puts "download remote file #{file} to work dir for #{member}"
      # todo: something something rclone, get the file down
    end

    def upload_to_member(member, file)
      puts "upload local file #{file} to remote dir for #{member}"
      # todo: something something rclone, upload scrub report to dropbox
    end

    def move_to_scrubbed_dir(member, file)
      scrubbed_dir = "#{Settings.scrubbed_files_dir}/#{member}"
      puts "move #{file} to #{scrubbed_dir}"
      FileUtils.mv(file, scrubbed_dir)
    end
  end
end
