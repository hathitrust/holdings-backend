# frozen_string_literal: true

require "spec_helper"
require "scrub/scrub_runner"
require "data_sources/directory_locator"

RSpec.describe Scrub::ScrubRunner do
  Settings.rclone_config_path = "/tmp/rclone.conf"
  Settings.local_member_dir = "/tmp/local_member_dir"
  Settings.remote_member_dir = "/tmp/remote_member_dir"

  let(:org1) { "test" }
  
  before(:each) do
    FileUtils.touch(Settings.rclone_config_path)
    FileUtils.mkdir_p(Settings.local_member_dir)
    FileUtils.mkdir_p(Settings.remote_member_dir)
  end

  after(:each) do
    FileUtils.rm_f(Settings.rclone_config_path)
    FileUtils.rm_rf(Settings.local_member_dir)
    FileUtils.rm_rf(Settings.remote_member_dir)
  end

  describe "#check_old_files" do
    it "local_d needs to exist first" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_dir, org1)
      expect { described_class.new.check_old_files(org1) }.to raise_error Utils::FileTransferError
      local_d.ensure!
      expect { described_class.new.check_old_files(org1) }.to_not raise_error
    end

    it "gets the files in the requested dir" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_dir, org1)
      local_d.ensure!
      FileUtils.touch(File.join(local_d.holdings_current, "a.txt"))
      FileUtils.touch(File.join(local_d.holdings_current, "b.txt"))
      expect(described_class.new.check_old_files(org1)).to eq ["a.txt", "b.txt"]
    end
  end
  
  describe "#check_new_files" do
    it "needs both remote and local dirs to exist" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_dir, org1)
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_dir, org1)
      # Neither exist, raise
      expect { described_class.new.check_new_files(org1) }.to raise_error Utils::FileTransferError
      # One exists, the other does not, raise
      local_d.ensure!
      expect { described_class.new.check_new_files(org1) }.to raise_error Utils::FileTransferError
      # Both exist, OK.
      remote_d.ensure!
      expect { described_class.new.check_new_files(org1) }.to_not raise_error
    end

    it "lists files in the remote dir whose names do not match old files in the local dir" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_dir, org1)
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_dir, org1)
      local_d.ensure!
      remote_d.ensure!
      # When there are no files:
      expect(described_class.new.check_new_files(org1)).to eq []

      # When there are remote files but no local files:
      FileUtils.touch(File.join(remote_d.holdings_current, "a.tsv"))
      expect(described_class.new.check_new_files(org1)).to eq ["a.tsv"]

      # When remote files == local files
      FileUtils.touch(File.join(local_d.holdings_current, "a.tsv"))
      expect(described_class.new.check_new_files(org1)).to eq []

      # When there is a remote file not in local
      FileUtils.touch(File.join(remote_d.holdings_current, "b.tsv"))
      expect(described_class.new.check_new_files(org1)).to eq ["b.tsv"]
    end
  end

  describe "#run_file" do
    it "runs" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_dir, org1)
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_dir, org1)
      local_d.ensure!
      remote_d.ensure!
      remote_file = File.join(remote_d.holdings_current, "test_mono_full_20220101.tsv")
      FileUtils.touch(remote_file)
      described_class.new.run_file(org1, remote_file)
    end
  end
  
  # test everything
  it "#run_some_members" do
    orgs = ["smu", "umich"]
    roots = [Settings.local_member_dir, Settings.remote_member_dir]
    # Make sure the dirs exist first
    roots.each do |root|
      orgs.each do |org|
        DataSources::DirectoryLocator.new(root, org).ensure!
      end
    end
    expect { described_class.new.run_some_members(orgs) }.not_to raise_error
  end
end
