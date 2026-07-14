# frozen_string_literal: true

require "clusterable/holding"
require "data_sources/directory_locator"
require "data_sources/ht_organizations"
require "date"
require "utils/line_counter"
require "loader/holding_loader"
require "scrub/autoscrub"
require "scrub/pre_load_backup"
require "scrub/record_counter"
require "scrub/scrub_runner"
require "scrub/malformed_file_error"
require "scrub/malformed_header_error"
require "scrub/type_check_error"
require "utils/slack_notifier"
require "spec_helper"

RSpec.describe Scrub::ScrubRunner do
  include_context "with tables for holdings"
  include_context "with mocked slack API endpoint"

  let(:org1) { "umich" }
  let(:remote_d) { DataSources::DirectoryLocator.new(Settings.remote_member_data, org1) }
  # Only set force_holding_loader_cleanup_test to true in testing.
  let(:sr) { described_class.new(org1, {"force_holding_loader_cleanup_test" => true}) }
  let(:mon_fixture_file_name) { "umich_mon_full_20220101.tsv" }
  let(:mon_fixture_file) { fixture(mon_fixture_file_name) }
  # `ser` and `mix` are for change of format tests.
  let(:ser_fixture_file_name) { "umich_ser_full_20220101.tsv" }
  let(:ser_fixture_file) { fixture(ser_fixture_file_name) }
  let(:mix_fixture_file_name) { "umich_mix_full_20220101.tsv" }
  let(:mix_fixture_file) { fixture(mix_fixture_file_name) }

  def count_loaded_files
    Services.holdings_db[:holdings_loaded_files].where(filename: mon_fixture_file_name).count
  end

  before(:each) do
    FileUtils.touch(Settings.rclone_config_path)
    FileUtils.mkdir_p(Settings.local_member_data)
    FileUtils.mkdir_p(Settings.remote_member_data)
  end

  describe ".new" do
    it "raises on nil organization" do
      expect {
        described_class.new(nil)
      }.to raise_error(/@organization/)
    end

    it "raises on unknown force parameter" do
      expect {
        described_class.new(org1, {"force" => "bogus"})
      }.to raise_error(/@force/)
    end

    it "raises on unknown force_holding_loader_cleanup_test parameter" do
      expect {
        described_class.new(org1, {"force_holding_loader_cleanup_test" => "bogus"})
      }.to raise_error(/@force_holding_loader_cleanup_test/)
    end

    it "raises on unknown type_check parameter" do
      expect {
        described_class.new(org1, {"type_check" => true})
      }.to raise_error(/@type_check/)
    end
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
      # Remote does not exist, raise
      expect { sr.check_new_files }.to raise_error Utils::FileTransferError
      # Remote exist, OK.
      remote_d.ensure!
      expect { sr.check_new_files }.to_not raise_error
    end

    it "lists files in the remote dir whose names do not match old files in the local dir" do
      local_d = DataSources::DirectoryLocator.new(Settings.local_member_data, org1)
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

      # When there are files that need to be ignored
      FileUtils.touch(File.join(remote_d.holdings_current, "b.log"))
      FileUtils.touch(File.join(remote_d.holdings_current, "c.xml"))
      FileUtils.touch(File.join(remote_d.holdings_current, "d.tar.gz"))
      expect(sr.check_new_files.first["Name"]).to eq "b.tsv"
      expect(sr.check_new_files.count).to eq(1)
    end

    it "ignores subdirectories in the remote current-year holdings directory" do
      remote_d.ensure!
      # Create subdirectory in the current year's holdings directory.
      ignore_dir = File.join(remote_d.holdings_current, "xml")
      FileUtils.mkdir_p(ignore_dir)
      # It's invisible to ScrubRunner
      expect(
        sr.check_new_files.select { |file| file["Name"] == "xml" }
      ).to be_empty
      # Clean up
      FileUtils.rm_rf(ignore_dir)
    end
  end

  describe "#run" do
    it "checks a member for new files and scrubs+loads them" do
      remote_d.ensure!
      # Copy fixture to "dropbox" so there is a "new file" to "download",
      FileUtils.cp(mon_fixture_file, remote_d.holdings_current)
      expect { sr.run }.to change { Clusterable::Holding.count }.by(6)
      log = "umich_mon_#{Time.new.strftime("%Y%m%d")}.log"
      expect(File.exist?(File.join(remote_d.holdings_current, log))).to be true
      # expect to see a row in holdings_loaded_files with filename=mon_fixture_file_name
      expect(count_loaded_files).to eq(1)
    end

    context "with multiple files including one with a bad header" do
      it "refuses to load any of them" do
        remote_d.ensure!
        FileUtils.cp(fixture("umich_mon_full_20220101_headerfail.tsv"), remote_d.holdings_current)
        FileUtils.cp(ser_fixture_file, remote_d.holdings_current)
        expect { sr.run }.to raise_error(Scrub::MalformedHeaderError)
          .and change { Clusterable::Holding.count }.by(0)
      end
    end

    context "with an unacceptable delta" do
      before(:each) do
        remote_d.ensure!
        FileUtils.cp(mon_fixture_file, remote_d.holdings_current)
        FileUtils.mkdir_p("#{ENV["TEST_TMP"]}/scrub_data/#{org1}/loaded/")
        File.open("#{ENV["TEST_TMP"]}/scrub_data/#{org1}/loaded/umich_mon_1.ndj", "w") do |file|
          1.upto(20) do |i|
            file.puts i
          end
        end
      end

      context "without use of --force" do
        it "raises `Scrub::MalformedFileError` and posts Slack notification" do
          stub = stub_slack_webhook(a_string_including("rejected")
            .and(a_string_including("umich"))
            .and(a_string_including("Diff too big")))

          expect {
            sr.run
          }.to raise_error(Scrub::MalformedFileError)
            .and change { Clusterable::Holding.count }.by(0)
          expect(stub).to have_been_requested.once
          # Log should have been uploaded.
          log = "umich_mon_#{Time.new.strftime("%Y%m%d")}.log"
          expect(File.exist?(File.join(remote_d.holdings_current, log))).to be true
        end
      end

      context "with use of --force" do
        it "accepts file" do
          sr_force = described_class.new(
            org1,
            {"force" => true, "force_holding_loader_cleanup_test" => true}
          )
          expect { sr_force.run }.to change { Clusterable::Holding.count }.by(6)
          # expect to see a row in holdings_loaded_files with filename=mon_fixture_file_name
          expect(count_loaded_files).to eq(1)
        end
      end
    end

    it "generates a backup file when overwriting holdings" do
      remote_d.ensure!
      # Copy fixture to "dropbox" so there is a "new file" to "download",
      FileUtils.cp(fixture("umich_mon_full_20220101.tsv"), remote_d.holdings_current)
      sr.run
      preloader = Scrub::PreLoadBackup.new(organization: org1, mono_multi_serial: "mon")
      # this may go away if we decide not to write empty backup file
      expect(File.exist?(preloader.backup_path)).to be true
      expect(Utils::LineCounter.new(preloader.backup_path).count_lines).to eq 0

      # Copy a new fixture to "dropbox" so there is a "new file" to "download",
      FileUtils.cp(fixture("umich_mon_full_20220102.tsv"), remote_d.holdings_current)
      described_class.new(org1, {"force_holding_loader_cleanup_test" => true}).run
      expect(File.exist?(preloader.backup_path)).to be true
      expect(Utils::LineCounter.new(preloader.backup_path).count_lines).to eq 6
    end

    it "posts a 'failed' Slack notification with error class on unexpected error" do
      remote_d.ensure!
      FileUtils.cp(mon_fixture_file, remote_d.holdings_current)
      allow_any_instance_of(Scrub::RecordCounter).to receive(:acceptable_diff?).and_raise(RuntimeError, "disk full")

      stub = stub_slack_webhook(a_string_including("failed")
        .and(a_string_including("umich"))
        .and(a_string_including("RuntimeError"))
        .and(a_string_including("disk full")))

      begin
        sr.run
      rescue
      end
      expect(stub).to have_been_requested.once
    end

    context "with type mismatch" do
      # This test acts as an integration test for Scrub::TypeChecker. Sort of.
      it "raises `TypeCheckError`" do
        remote_d.ensure!
        # Copy fixture to "dropbox" so there is a "new file" to "download",
        FileUtils.cp(mon_fixture_file, remote_d.holdings_current)
        # In this scenario we have already loaded a mix file,
        # so TypeChecker should alert about the mismatch.
        load_test_data(build(:holding, organization: org1, mono_multi_serial: "mix"))
        expect { sr.run }.to raise_error(Scrub::TypeCheckError, /There is a mismatch in item types./)
      end

      it "posts a Slack notification on type check rejection" do
        remote_d.ensure!
        FileUtils.cp(mon_fixture_file, remote_d.holdings_current)
        load_test_data(build(:holding, organization: org1, mono_multi_serial: "mix"))

        stub = stub_slack_webhook(a_string_including("umich")
          .and(a_string_including("rejected"))
          .and(a_string_including("mismatch")))

        expect { sr.run }.to raise_error(Scrub::TypeCheckError)
        expect(stub).to have_been_requested.once
      end

      context "with format change spm/mpm/ser -> mon/ser" do
        let(:sr) { described_class.new(org1, {"force_holding_loader_cleanup_test" => true, "type_check" => "delete"}) }

        it "deletes `spm` and `mpm` data after backing it up" do
          remote_d.ensure!
          # Copy fixtures to "dropbox" so there is a "new file" to "download",
          FileUtils.cp(mon_fixture_file, remote_d.holdings_current)
          FileUtils.cp(ser_fixture_file, remote_d.holdings_current)
          # Load 6 each spm, mpm, and ser
          records = []
          6.times do
            records << build(:holding, organization: org1, mono_multi_serial: "spm")
            records << build(:holding, organization: org1, mono_multi_serial: "mpm")
            records << build(:holding, organization: org1, mono_multi_serial: "ser")
          end
          load_test_data(*records)
          # We expect a notification about the file deletion
          stub = stub_slack_webhook(a_string_including("Holdings deletion"))
          # Scrub will load 6 each mon, ser for a net decrement of 6.
          expect { sr.run }.to change { Clusterable::Holding.count }.by(-6)
          # No spm or mpm remain
          expect(Clusterable::Holding.table.where(organization: org1, mono_multi_serial: "mpm").count).to eq(0)
          expect(Clusterable::Holding.table.where(organization: org1, mono_multi_serial: "spm").count).to eq(0)
          # Now we have 6 mon and 6 ser
          expect(Clusterable::Holding.table.where(organization: org1, mono_multi_serial: "mon").count).to eq(6)
          expect(Clusterable::Holding.table.where(organization: org1, mono_multi_serial: "ser").count).to eq(6)
          # All data was backed up
          ["spm", "mpm", "ser"].each do |type|
            expect(
              File.exist?(
                Scrub::PreLoadBackup.new(organization: org1, mono_multi_serial: type).backup_path
              )
            ).to eq(true)
          end
          # One Slack notification for each of spm and mpm
          expect(stub).to have_been_requested.twice
        end
      end

      context "with format change mon/ser -> mix" do
        let(:sr) { described_class.new(org1, {"force_holding_loader_cleanup_test" => true, "type_check" => "delete"}) }

        it "deletes `mon` and `ser` data after backing it up" do
          remote_d.ensure!
          # Copy fixture to "dropbox" so there is a "new file" to "download",
          FileUtils.cp(mix_fixture_file, remote_d.holdings_current)
          # Load 6 each mon and ser
          records = []
          6.times do
            records << build(:holding, organization: org1, mono_multi_serial: "mon")
            records << build(:holding, organization: org1, mono_multi_serial: "ser")
          end
          load_test_data(*records)
          # We expect notifications about the file deletion
          stub = stub_slack_webhook(a_string_including("Holdings deletion"))
          # Scrub will load 6 `mix` for a net decrement of 6.
          expect { sr.run }.to change { Clusterable::Holding.count }.by(-6)
          # No mon or ser remain
          expect(Clusterable::Holding.table.where(organization: org1, mono_multi_serial: "mon").count).to eq(0)
          expect(Clusterable::Holding.table.where(organization: org1, mono_multi_serial: "ser").count).to eq(0)
          # Now we have 6 mix
          expect(Clusterable::Holding.table.where(organization: org1, mono_multi_serial: "mix").count).to eq(6)
          # All data was backed up
          ["mon", "ser"].each do |type|
            expect(
              File.exist?(
                Scrub::PreLoadBackup.new(organization: org1, mono_multi_serial: type).backup_path
              )
            ).to eq(true)
          end
          # One Slack notification for each of mon and ser
          expect(stub).to have_been_requested.twice
        end
      end

      context "adding mon to existing ser with --type-check=append" do
        let(:sr) { described_class.new(org1, {"force_holding_loader_cleanup_test" => true, "type_check" => "append"}) }

        it "loads mon without deleting ser" do
          remote_d.ensure!
          # Copy fixture to "dropbox" so there is a "new file" to "download",
          FileUtils.cp(mon_fixture_file, remote_d.holdings_current)
          # Load 6 ser
          records = []
          6.times do
            records << build(:holding, organization: org1, mono_multi_serial: "ser")
          end
          load_test_data(*records)
          # Scrub loads 6 `mon` for a net increment of 6.
          expect { sr.run }.to change { Clusterable::Holding.count }.by(6)
          # mon and ser remain
          expect(Clusterable::Holding.table.where(organization: org1, mono_multi_serial: "mon").count).to eq(6)
          expect(Clusterable::Holding.table.where(organization: org1, mono_multi_serial: "ser").count).to eq(6)
        end
      end
    end
  end

  describe "#scrub_file" do
    it "downloads and scrubs a specific file without loading" do
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_data, org1)
      remote_d.ensure!
      FileUtils.cp(mon_fixture_file, remote_d.holdings_current)
      preflight = nil
      expect { preflight = sr.scrub_file(mon_fixture_file_name) }.not_to change { Clusterable::Holding.count }
      expect(preflight.scrubber.scrubbed_file).not_to be nil
      expect(File.exist?(preflight.scrubber.scrubbed_file)).to be true
      # File should still appear as new since the local cache was not touched
      expect(sr.check_new_files.map { |f| f["Name"] }).to include(mon_fixture_file_name)
    end

    it "detects error from a malformed file" do
      remote_d = DataSources::DirectoryLocator.new(Settings.remote_member_data, org1)
      remote_d.ensure!
      FileUtils.cp(fixture("umich_mon_full_20220101_headerfail.tsv"), remote_d.holdings_current)
      expect {
        sr.scrub_file("umich_mon_full_20220101_headerfail.tsv")
      }.to raise_error(Scrub::MalformedHeaderError)
    end
  end
end
