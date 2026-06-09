# frozen_string_literal: true

require "open3"

require "utils/tar"
require "spec_helper"

RSpec.describe Utils::Tar do
  let(:tar_gz_fixture) { fixture("exlibris_ser_in.tar.gz") }
  let(:tar_gz_fixture_contents) { ["exlibris_ser_in.xml"] }
  let(:tar) { described_class.new(path: tar_gz_fixture) }
  let(:tmp_directory) { ENV["TEST_TMP"] }

  describe "#initialize" do
    it "returns #{described_class}" do
      expect(tar).to be_a(described_class)
    end

    it "exposes `path`" do
      expect(tar.path).to eq(tar_gz_fixture)
    end

    it "raises when created with nonexistent file" do
      expect {
        described_class.new(path: "/no/such/file.tar.gz")
      }.to raise_error(/not found/)
    end
  end

  describe "#list" do
    it "returns the expected constituent files in an Array" do
      expect(tar.list).to eq(tar_gz_fixture_contents)
    end

    it "raises when `tar` cannot read the archive" do
      expect {
        described_class.new(path: fixture("exlibris_ser_in.xml")).list
      }.to raise_error(/could not list contents/)
    end
  end

  describe "#extract" do
    it "extracts the file" do
      destination = File.join(tmp_directory, "test")
      tar.extract(file_name: tar_gz_fixture_contents.first, destination_path: destination)
      expect(File.exist?(destination)).to eq(true)
      expect(File.size(destination)).to eq(File.size(fixture("exlibris_ser_in.xml")))
    end

    it "raises when destination cannot be created" do
      expect {
        tar.extract(file_name: tar_gz_fixture_contents.first, destination_path: "/no/such/path")
      }.to raise_error(Errno::ENOENT)
    end

    it "raises when requested file_name does not exist" do
      expect {
        tar.extract(file_name: "no such file", destination_path: File.join(tmp_directory, "test"))
      }.to raise_error(/could not extract/)
    end

    it "does not execute malicious filename bits" do
      # Create an evil file to include
      evil_file_name = "blah'; rm 'critical_data'; echo 'gotcha"
      evil_file = File.join(tmp_directory, evil_file_name)
      File.open(evil_file, "w") do |file|
        file.puts "haha!"
      end

      evil_archive = File.join(tmp_directory, "evil_archive.tar.gz")
      _out_err, _status = Open3.capture2e("/usr/bin/tar", "-czvf", evil_archive, evil_file)
      file_list = described_class.new(path: evil_archive).list
      destination = File.join(tmp_directory, "test")
      # Create a canary
      `touch critical_data`
      described_class.new(path: evil_archive).extract(file_name: file_list.first, destination_path: destination)
      expect(File.exist?("critical_data")).to eq(true)

      # Now try it the naive way...
      cmd = "tar -xzf #{evil_archive} '#{file_list.first}' -O > #{destination}"
      system(cmd)
      expect(File.exist?("critical_data")).to eq(false)
    end
  end
end
