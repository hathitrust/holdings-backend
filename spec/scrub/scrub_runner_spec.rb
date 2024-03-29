# frozen_string_literal: true

require "data_sources/directory_locator"
require "data_sources/ht_organizations"
require "date"
require "loader/holding_loader"
require "scrub/autoscrub"
require "scrub/record_counter"
require "scrub/scrub_runner"
require "spec_helper"

RSpec.describe Scrub::ScrubRunner do
  let(:org1) { "umich" }
  # Only set force_holding_loader_cleanup_test to true in testing.
  let(:sr) { described_class.new(org1, {"force_holding_loader_cleanup_test" => true}) }
  let(:fixture_file) { "spec/fixtures/umich_mon_full_20220101.tsv" }

  before(:each) do
    FileUtils.touch(Settings.rclone_config_path)
    FileUtils.mkdir_p(Settings.local_member_data)
    FileUtils.mkdir_p(Settings.remote_member_data)
  end

  describe "#check_old_files" do
    it "create the local directory if if does not exist" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_data, org1)
      FileUtils.rm_rf(local_d.holdings_current)
      # nothing there, at first.
      expect(File.exist?(local_d.holdings_current)).to be false
      sr.check_old_files
      expect(File.exist?(local_d.holdings_current)).to be true
    end

    it "finds the files in the local dir" do
      # Get a directory locator for local files.
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_data, org1)
      # Put files in local dir.
      FileUtils.mkdir_p(local_d.holdings_current)
      FileUtils.touch(File.join(local_d.holdings_current, "a.txt"))
      FileUtils.touch(File.join(local_d.holdings_current, "b.txt"))
      # ScrubRunner sees them.
      expect(sr.check_old_files.map { |f| f["Name"] }).to eq ["a.txt", "b.txt"]
    end
  end

  describe "#check_new_files" do
    it "needs remote dir to exist" do
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_data, org1)
      # Remote does not exist, raise
      expect { sr.check_new_files }.to raise_error Utils::FileTransferError
      # Remote exist, OK.
      remote_d.ensure!
      expect { sr.check_new_files }.to_not raise_error
    end

    it "lists files in the remote dir whose names do not match old files in the local dir" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_data, org1)
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_data, org1)
      remote_d.ensure!
      # When there are no files:
      expect(sr.check_new_files).to eq []

      # When there are remote files but no local files:
      FileUtils.touch(File.join(remote_d.holdings_current, "a.tsv"))
      expect(sr.check_new_files.first["Name"]).to eq "a.tsv"

      # When remote files == local files
      FileUtils.touch(File.join(local_d.holdings_current, "a.tsv"))
      expect(sr.check_new_files).to eq []

      # When there is a remote file not in local
      FileUtils.touch(File.join(remote_d.holdings_current, "b.tsv"))
      expect(sr.check_new_files.first["Name"]).to eq "b.tsv"
    end
  end

  describe "#run" do
    it "checks a member for new files and scrubs+loads them" do
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_data, org1)
      remote_d.ensure!
      # Copy fixture to "dropbox" so there is a "new file" to "download",
      FileUtils.cp(fixture_file, remote_d.holdings_current)
      expect { sr.run }.to change { cluster_count(:holdings) }.by(6)
    end
  end

  describe "#run_file" do
    it "run for a specific remote file" do
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_data, org1)
      remote_d.ensure!
      # Copy fixture to "dropbox" so there is a "new file" to "download",
      FileUtils.cp(fixture_file, remote_d.holdings_current)
      remote_file = sr.check_new_files.first
      expect { sr.run_file(remote_file) }.to change { cluster_count(:holdings) }.by(6)
      # Expect log file to end up in the remote dir
      log = "umich_mon_#{Time.new.strftime("%Y%m%d")}.log"
      expect(File.exist?(File.join(remote_d.holdings_current, log))).to be true
    end
    it "will refuse a file if it breaks Settings.scrub_line_count_diff_max" do
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_data, org1)
      remote_d.ensure!
      # Copy fixture to "dropbox" so there is a "new file" to "download",
      FileUtils.cp(fixture_file, remote_d.holdings_current)
      remote_file = sr.check_new_files.first

      FileUtils.mkdir_p("#{ENV["TEST_TMP"]}/scrub_data/#{org1}/loaded/")
      File.open("#{ENV["TEST_TMP"]}/scrub_data/#{org1}/loaded/umich_mon_1.ndj", "w") do |file|
        1.upto(20) do |i|
          file.puts i
        end
      end
      expect { sr.run_file(remote_file) }.to change { cluster_count(:holdings) }.by(0)
      # Log should have been uploaded.
      log = "umich_mon_#{Time.new.strftime("%Y%m%d")}.log"
      expect(File.exist?(File.join(remote_d.holdings_current, log))).to be true

      # We can still force the file through.
      sr_force = described_class.new(
        org1,
        {"force" => true, "force_holding_loader_cleanup_test" => true}
      )
      expect { sr_force.run_file(remote_file) }.to change { cluster_count(:holdings) }.by(6)
    end
  end
end
