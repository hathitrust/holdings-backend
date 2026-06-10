require "spec_helper"
require "alma_holdings"
require "marc"

RSpec.describe AlmaHoldings do
  let(:remote_directory) { ENV["TEST_TMP"] }
  let(:organization) { "umich" }
  let(:holdings) { described_class.new(organization: organization, remote_directory: remote_directory) }

  describe "#initialize" do
    it "returns #{described_class}" do
      expect(described_class.new(organization: organization)).to be_a described_class
    end

    it "requires organization" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it "exposes organization" do
      expect(described_class.new(organization: organization).organization).to eq(organization)
    end

    it "exposes remote directory" do
      expect(described_class.new(organization: organization, remote_directory: "test").remote_directory).to eq("test")
    end
  end

  describe "#run" do
    it "processes two remote files and uploads two derivatives" do
      FileUtils.cp(fixture("exlibris_ser_in.tar.gz"), remote_directory)
      FileUtils.cp(fixture("exlibris_mon_in.xml"), remote_directory)
      holdings.run
      expect(Dir.glob("*.tsv", base: remote_directory).count).to eq(2)
    end

    it "warns and exits if no XML files are found" do
      allow(Services.logger).to receive(:warn)
      holdings.run
      expect(Services.logger).to have_received(:warn).with(/no xml files/i)
    end

    it "cleans up after itself in case of error" do
      holdings_fail = described_class.new(organization: organization, remote_directory: "/no/such/directory")
      local_dir = holdings_fail.local_directory
      expect {
        holdings_fail.run
      }.to raise_error(StandardError)
      expect(File.directory?(local_dir)).to eq(false)
    end
  end

  describe "#cleanup" do
    it "removes the local directory" do
      local_dir = holdings.local_directory
      holdings.cleanup
      expect(File.directory?(local_dir)).to eq(false)
    end
  end

  describe "#upload" do
    it "copies a file from the local directory to the remote" do
      local_file = File.join(holdings.local_directory, "umich_mon.tsv")
      remote_file = File.join(holdings.remote_directory, "umich_mon.tsv")
      FileUtils.touch(local_file)
      # Make sure remote file is not hanging around already
      expect(File.exist?(remote_file)).to eq(false)
      holdings.upload(path: local_file)
      expect(File.exist?(remote_file)).to eq(true)
    end
  end

  describe "#candidates" do
    it "raises if remote dir does not exist" do
      expect {
        described_class.new(organization: organization, remote_directory: "test").candidates
      }.to raise_error Utils::FileTransferError
    end

    it "returns empty array when no applicable files in the remote dir" do
      # When there are no files:
      expect(holdings.candidates).to eq []
    end

    it "returns .tar.gz and .xml files" do
      # When there are various remote files to choose from:
      FileUtils.touch(File.join(remote_directory, "a.tsv"))
      FileUtils.touch(File.join(remote_directory, "b.xml"))
      FileUtils.touch(File.join(remote_directory, "c.tar.gz"))
      FileUtils.mkdir(File.join(remote_directory, "d.d"))
      expect(
        holdings.candidates.map { |c| c["Name"] }
      ).to eq ["b.xml", "c.tar.gz"]
    end
  end

  describe "#download" do
    it "downloads a candidates file" do
      FileUtils.touch(File.join(remote_directory, "b.xml"))
      downloaded_file = holdings.download(file_h: holdings.candidates.first)
      expect(File.exist?(downloaded_file)).to eq(true)
    end
  end

  describe "#extract" do
    it "passes XML file unchanged" do
      xml_file = File.join(holdings.local_directory, "b.xml")
      FileUtils.touch(xml_file)
      expect(holdings.extract(path: xml_file)).to eq(xml_file)
    end

    it "extracts a .tar.gz file" do
      xml_file = fixture("exlibris_ser_in.tar.gz")
      FileUtils.cp(xml_file, holdings.local_directory)
      expect(holdings.extract(path: xml_file)).to match(/umich_ser_.+?\.xml/)
    end

    it "raises if more than one file in the archive" do
      # Stick some fixtures in a gzipped tarball
      gz = File.join(holdings.local_directory, "test.tar.gz")
      # Without --absolute-names tar emits "Removing leading `/'..." noise
      system("tar -czPf #{gz} #{fixture("exlibris_ser_in.xml")} #{fixture("exlibris_mon_in.xml")}")
      expect {
        holdings.extract(path: gz)
      }.to raise_error(/unexpected contents/)
    end
  end
end
