# frozen_string_literal: true

require "utils/file_transfer"
require "spec_helper"
require "services"

# Since rclone does not care what the remote location is,
# and since we do not have a separate test dropbox,
# these tests use directories under /tmp/ as a fake remote location.
#
# So, CAVEAT EMPTOR, it does not truly test rclone's ability to
# transfer files to a remote location, just that the wrapper code
# (Utils::FileTransfer) does what it promises.

RSpec.describe Utils::FileTransfer do
  let(:ft) { described_class.new }
  # Do not change local_dir or remote_dir to something important,
  # as they WILL be deleted during these tests.
  let(:local_dir) { "/tmp/file_transfer_test/local" }
  let(:remote_dir) { "/tmp/file_transfer_test/remote" }
  let(:local_file_name) { "test_file_a.txt" }
  let(:remote_file_name) { "test_file_b.txt" }
  let(:local_file_path) { "#{local_dir}/#{local_file_name}" }
  let(:remote_file_path) { "#{remote_dir}/#{remote_file_name}" }
  let(:conf) { "config/rclone.conf" }

  # Clean up temporary files and directories
  before(:each) do
    Settings.rclone_config_path = conf
    FileUtils.mkdir_p local_dir
    FileUtils.mkdir_p remote_dir
    FileUtils.rm("#{local_dir}/*", force: true)
    FileUtils.rm("#{remote_dir}/*", force: true)
    FileUtils.touch local_file_path
    FileUtils.touch remote_file_path
    FileUtils.touch conf # if it does not exist FileTransfer complains
  end

  after(:each) do
    FileUtils.rm_rf local_dir
    FileUtils.rm_rf remote_dir
  end

  context "initialize" do
    it "requires conf file to be set in Settings" do
      expect { described_class.new }.not_to raise_error
      Settings.rclone_config_path = nil
      expect { described_class.new }.to raise_error
    end

    it "requires conf file to exist" do
      expect { described_class.new }.not_to raise_error
      FileUtils.rm conf
      expect { described_class.new }.to raise_error
    end
  end

  context "listing remote files" do
    it "ls_remote_dir" do
      parsed_json = ft.ls_remote_dir(remote_dir)
      expect(parsed_json).to be_a Array
      expect(parsed_json.size).to eq 1
      expect(parsed_json.first).to be_a Hash
      expect(parsed_json.first.keys.sort).to eq %w[IsDir MimeType ModTime Name Path Size]
      expect(parsed_json.first["Name"]).to eq remote_file_name
    end
  end

  context "transferring files" do
    it "upload" do
      expect(ft.ls_remote_dir(remote_dir).count { |h| h["Name"] == local_file_name }).to eq 0
      ft.upload(local_file_path, remote_dir)
      expect(ft.ls_remote_dir(remote_dir).count { |h| h["Name"] == local_file_name }).to eq 1
    end

    it "download" do
      expect(File.exist?("#{local_dir}/#{remote_file_name}")).to be false
      ft.download(remote_file_path, local_dir)
      expect(File.exist?("#{local_dir}/#{remote_file_name}")).to be true
    end
  end
end
