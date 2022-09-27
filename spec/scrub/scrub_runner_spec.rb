# frozen_string_literal: true

require "spec_helper"
require "scrub/scrub_runner"
require "data_sources/directory_locator"
require "data_sources/ht_organizations"

RSpec.describe Scrub::ScrubRunner do
  Settings.rclone_config_path = "/tmp/rclone.conf"
  Settings.local_member_dir = "/tmp/local_member_dir"
  Settings.remote_member_dir = "/tmp/remote_member_dir"
  Settings.scrub_chunk_work_dir = "/tmp"

  let(:org1) { "umich" }
  let(:sr) { described_class.new(org1) }
  let(:fixture_file) { "/usr/src/app/spec/fixtures/umich_mono_full_20220101.tsv" }

  before(:each) do
    FileUtils.touch(Settings.rclone_config_path)
    FileUtils.mkdir_p(Settings.local_member_dir)
    FileUtils.mkdir_p(Settings.remote_member_dir)
    stub_request(:get, OCLC_URL).to_return(body: '{ "oclcNumber": "1000000000" }')
  end

  after(:each) do
    FileUtils.rm_f(Settings.rclone_config_path)
    FileUtils.rm_rf(Settings.local_member_dir)
    FileUtils.rm_rf(Settings.remote_member_dir)
  end

  describe "#check_old_files" do
    it "local_d needs to exist first" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_dir, org1)
      # nothing there, at first.
      expect { sr.check_old_files }.to raise_error Utils::FileTransferError
      # mkdir the missing dirs:
      local_d.ensure!
      expect { sr.check_old_files }.to_not raise_error
    end

    it "finds the files in the local dir" do
      # Get a directory locator for local files.
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_dir, org1)
      local_d.ensure!
      # Put files in local dir.
      FileUtils.touch(File.join(local_d.holdings_current, "a.txt"))
      FileUtils.touch(File.join(local_d.holdings_current, "b.txt"))
      # ScrubRunner sees them.
      expect(sr.check_old_files.map { |f| f["Name"] }).to eq ["a.txt", "b.txt"]
    end
  end

  describe "#check_new_files" do
    it "needs both remote and local dirs to exist" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_dir, org1)
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_dir, org1)
      # Neither exist, raise
      expect { sr.check_new_files }.to raise_error Utils::FileTransferError
      # One exists, the other does not, raise
      local_d.ensure!
      expect { sr.check_new_files }.to raise_error Utils::FileTransferError
      # Both exist, OK.
      remote_d.ensure!
      expect { sr.check_new_files }.to_not raise_error
    end

    it "lists files in the remote dir whose names do not match old files in the local dir" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_dir, org1)
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_dir, org1)
      local_d.ensure!
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
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_dir, org1)
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_dir, org1)
      local_d.ensure!
      remote_d.ensure!
      # Copy fixture to "dropbox" so there is a "new file" to "download",
      FileUtils.cp(fixture_file, remote_d.holdings_current)
      sr.run
    end
  end

  describe "#run_file" do
    it "run for a specific remote file" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_dir, org1)
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_dir, org1)
      local_d.ensure!
      remote_d.ensure!
      # Copy fixture to "dropbox" so there is a "new file" to "download",
      FileUtils.cp(fixture_file, remote_d.holdings_current)
      remote_file = sr.check_new_files.first
      sr.run_file(remote_file)
    end
  end
end
