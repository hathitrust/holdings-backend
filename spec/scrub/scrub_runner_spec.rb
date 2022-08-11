# frozen_string_literal: true

require "spec_helper"
require "scrub/scrub_runner"
require "data_sources/directory_locator"

RSpec.describe Scrub::ScrubRunner do
  Settings.rclone_config_path = "/tmp/rclone.conf"
  Settings.local_member_dir = "/tmp/local_member_dir"
  Settings.remote_member_dir = "/tmp/remote_member_dir"

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

  # test everything
  it "#run_some_members" do
    orgs  = ["smu", "umich"]
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
