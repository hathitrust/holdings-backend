# frozen_string_literal: true

require "data_sources/directory_locator"
require "scrub/preflight"
require "scrub/scrub_output_structure"
require "spec_helper"

RSpec.describe Scrub::Preflight do
  let(:org1) { "umich" }
  let(:remote_d) { DataSources::DirectoryLocator.new(Settings.remote_member_data, org1) }
  let(:local_d) { DataSources::DirectoryLocator.new(Settings.local_member_data, org1) }
  let(:mon_fixture) { "umich_mon_full_20220101.tsv" }
  let(:mon_fixture_path) { fixture(mon_fixture) }
  let(:bad_mon_fixture) { "umich_mon_full_20220101_headerfail.tsv" }
  let(:bad_mon_fixture_path) { fixture(bad_mon_fixture) }
  let(:preflight) { described_class.new(organization: org1, remote_file: mon_fixture) }

  before(:each) do
    FileUtils.touch(Settings.rclone_config_path)
    FileUtils.mkdir_p(Settings.local_member_data)
    FileUtils.mkdir_p(Settings.remote_member_data)
  end

  describe "initialize" do
    it "creates #{described_class}" do
      expect(preflight).to be_a(described_class)
    end
  end

  describe "run" do
    context "with a well-formed file" do
      it "indicates success and leaves downloaded file in place" do
        remote_d.ensure!
        local_d.ensure!
        FileUtils.cp(mon_fixture_path, remote_d.holdings_current)
        preflight.run
        expect(File.exist?(preflight.downloaded_file)).to eq(true)
      end
    end

    context "with a bogus file" do
      it "raises MalformedFileError failure and leaves downloaded file in place" do
        remote_d.ensure!
        local_d.ensure!
        FileUtils.cp(bad_mon_fixture_path, remote_d.holdings_current)
        preflight = described_class.new(organization: org1, remote_file: bad_mon_fixture)
        expect {
          preflight.run
        }.to raise_error(StandardError)
        expect(File.exist?(preflight.downloaded_file)).to eq(true)
      end
    end

    context "with a temporary directory" do
      it "uses it for downloaded files" do
        remote_d.ensure!
        local_d.ensure!
        FileUtils.cp(mon_fixture_path, remote_d.holdings_current)
        Dir.mktmpdir do |tmp_dir|
          preflight = described_class.new(organization: org1, remote_file: mon_fixture, local_dir: tmp_dir)
          preflight.run
          # Is there more in the temp directory than just . and ..?
          expect(Dir.entries(tmp_dir).count).to be > 2
        end
      end
    end

    context "with a > 5% increase in numbers" do
      it "indicates failure and cleans up" do
        remote_d.ensure!
        local_d.ensure!
        FileUtils.cp(mon_fixture_path, remote_d.holdings_current)
        output_struct = Scrub::ScrubOutputStructure.new(org1)
        # Put a bogus already-loaded file in place with a minimal number of lines.
        bogus_file = File.join(output_struct.member_loaded, "umich_mon_full_20210101.ndj")
        File.open(bogus_file, "w") do |fh|
          fh.puts <<~JSON
            {"ocn": 3}
            {"ocn": 4}
          JSON
        end
        expect {
          preflight.run
        }.to raise_error(Scrub::MalformedFileError)
      end
    end
  end
end
