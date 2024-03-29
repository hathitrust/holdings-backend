# frozen_string_literal: true

require "utils/file_transfer"
require "utils/file_transfer_error"
require "spec_helper"
require "services"

# Since rclone does not care what the remote location is,
# and since we do not have a separate test dropbox,
# these tests use directories under TEST_TMP as a fake remote location.
#
# So, CAVEAT EMPTOR, it does not truly test rclone's ability to
# transfer files to a remote location, just that the wrapper code
# (Utils::FileTransfer) does what it promises.

RSpec.describe Utils::FileTransfer do
  let(:ft) { described_class.new }
  let(:local_dir) { "#{ENV["TEST_TMP"]}/file_transfer_test/local" }
  let(:remote_dir) { "#{ENV["TEST_TMP"]}/file_transfer_test/remote" }
  let(:local_file_name) { "test_file_a.txt" }
  let(:remote_file_name) { "test_file_b.txt" }
  let(:local_file_path) { "#{local_dir}/#{local_file_name}" }
  let(:remote_file_path) { "#{remote_dir}/#{remote_file_name}" }
  let(:conf) { Settings.rclone_config_path }
  let(:missing_dir) { "/nonexistent/foo" }
  let(:missing_file) { "/nonexistent/foo.txt" }

  # Clean up temporary files and directories
  before(:each) do
    FileUtils.touch conf # if it does not exist FileTransfer complains
    FileUtils.mkdir_p local_dir
    FileUtils.mkdir_p remote_dir
    FileUtils.rm("#{local_dir}/*", force: true)
    FileUtils.rm("#{remote_dir}/*", force: true)
    FileUtils.touch local_file_path
    FileUtils.touch remote_file_path
  end

  describe "initialize" do
    it "requires conf file to be set in Settings" do
      expect { described_class.new }.not_to raise_error
      Settings.rclone_config_path = nil
      expect { described_class.new }.to raise_error RuntimeError
    end
    it "requires conf file to exist" do
      expect { described_class.new }.not_to raise_error
      FileUtils.rm conf
      expect { described_class.new }.to raise_error RuntimeError
    end
  end

  describe "listing remote files" do
    it "provides json file listing" do
      parsed_json = ft.lsjson(remote_dir)
      expect(parsed_json).to be_a Array
      expect(parsed_json.size).to eq 1
      expect(parsed_json.first).to be_a Hash
      expect(parsed_json.first.keys.sort).to eq %w[IsDir MimeType ModTime Name Path Size]
      expect(parsed_json.first["Name"]).to eq remote_file_name
    end
    it "throws an error if dir does not exist" do
      expect(ft.exists?(remote_dir)).to be true
      expect { ft.lsjson(remote_dir) }.not_to raise_error
      expect(ft.exists?(missing_dir)).to be false
      expect { ft.lsjson(missing_dir) }.to raise_error Utils::FileTransferError
    end
  end

  describe "#mkdir_p" do
    it "can make a dir that does not exist" do
      new_dir = "#{local_dir}/nope"
      expect(ft.exists?(new_dir)).to be false
      ft.mkdir_p(new_dir)
      expect(ft.exists?(new_dir)).to be true
    end
    it "makes the whole path even if missing, like mkdir -p" do
      new_dir = "#{local_dir}/nope1/nope2/nope3"
      expect(ft.exists?(new_dir)).to be false
      ft.mkdir_p(new_dir)
      expect(ft.exists?(new_dir)).to be true
    end
  end

  describe "#upload" do
    it "puts a file in the expected location" do
      expect(ft.lsjson(remote_dir).count { |h| h["Name"] == local_file_name }).to eq 0
      ft.upload(local_file_path, remote_dir)
      expect(ft.lsjson(remote_dir).count { |h| h["Name"] == local_file_name }).to eq 1
    end
    it "raises if file does not exist" do
      expect { ft.upload(missing_file, remote_dir) }.to raise_error Utils::FileTransferError
    end
    it "raises if dir does not exist" do
      expect { ft.upload(local_file_path, missing_dir) }.to raise_error Utils::FileTransferError
    end
  end

  describe "#download" do
    it "puts a file in the expected location" do
      expect(File.exist?("#{local_dir}/#{remote_file_name}")).to be false
      ft.download(remote_file_path, local_dir)
      expect(File.exist?("#{local_dir}/#{remote_file_name}")).to be true
    end
    it "raises if file does not exist" do
      expect { ft.download(missing_file, remote_dir) }.to raise_error Utils::FileTransferError
    end
    it "raises if dir does not exist" do
      expect { ft.download(local_file_path, missing_dir) }.to raise_error Utils::FileTransferError
    end
  end
end
