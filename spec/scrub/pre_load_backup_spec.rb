# frozen_string_literal: true

require "loader/holding_loader"
require "loader/file_loader"
require "scrub/pre_load_backup"
require "utils/line_counter"

RSpec.describe Scrub::PreLoadBackup do
  let(:umich) { "umich" }
  let(:smu) { "smu" }
  let(:mon) { "mon" }
  let(:ser) { "ser" }
  let(:table) { Services.holdings_db[:holdings] }
  let(:affected_count) { 3 }
  let(:unaffected_count) { 9 }
  let(:umich_mon_backup) { described_class.new(organization: umich, mono_multi_serial: mon) }
  let(:line_counter) { Utils::LineCounter.new(umich_mon_backup.backup_path) }

  include_context "with tables for holdings"

  before(:each) do
    make_test_records!
  end

  def make_test_records!
    # Add 3 mon and 3 ser holdings for umich and smu.
    # This makes a total of 12 records.
    # All tests should only affect 3 records (umich&mon),
    # and leave the other 9 records (smu&mon, smu&ser, umich&ser) unaffected.
    [umich, smu].each do |org|
      [mon, ser].each do |type|
        1.upto(affected_count) do
          load_test_data(build(:holding, organization: org, mono_multi_serial: type))
        end
      end
    end
  end

  describe "#initialize" do
    it "initializes and has working attr_readers" do
      expect(umich_mon_backup).to be_a described_class
      expect(umich_mon_backup.organization).to eq umich
      expect(umich_mon_backup.mono_multi_serial).to eq mon
      expect(umich_mon_backup.match_count).to eq affected_count
    end

    it "raises if Settings.backup_dir is not set" do
      allow(Settings).to receive(:backup_dir) { nil }
      expect { umich_mon_backup }.to raise_error(/backup_dir/)
    end

    it "creates backup_dir if necessary" do
      allow(Settings).to receive(:backup_dir) { File.join(ENV["TEST_TMP"], "this_is_the_backup_dir") }
      expect(File.exist?(Settings.backup_dir)).to be false
      umich_mon_backup
      expect(File.exist?(Settings.backup_dir)).to be true
    end
  end

  describe "#write_backup_file" do
    it "generates a backup file with the expected line counts" do
      umich_mon_backup.write_backup_file
      expect(File.exist?(umich_mon_backup.backup_path)).to be true
      expect(line_counter.count_lines).to eq affected_count
    end
  end

  describe "#mark_for_deletion" do
    it "marks the specified holdings for deletion" do
      # None marked before marking
      expect(table.where(delete_flag: 1).count).to eq 0
      umich_mon_backup.mark_for_deletion
      # Some marked after marking
      expect(table.where(delete_flag: 1).count).to eq affected_count
      expect(table.where(delete_flag: 0).count).to eq unaffected_count
    end
  end

  describe "#delete_marked!" do
    it "deletes records marked by mark_for_deletion" do
      umich_mon_backup.mark_for_deletion
      # Some marked before deletion
      expect(table.where(delete_flag: 1).count).to eq affected_count
      umich_mon_backup.delete_marked!
      # None marked before deletion
      expect(table.where(delete_flag: 1).count).to eq 0
      expect(table.count).to eq unaffected_count
    end
  end

  describe "round-tripping" do
    it "generates the same identical backup file after a successful round-trip" do
      # Expect full count
      expect(umich_mon_backup.match_count).to eq affected_count

      # Back up and delete, expect empty count
      umich_mon_backup.write_backup_file
      first_checksum = `md5sum #{umich_mon_backup.backup_path}`
      umich_mon_backup.mark_for_deletion
      umich_mon_backup.delete_marked!
      expect(umich_mon_backup.match_count).to eq 0

      # Load backup, expect full count again
      loader = Loader::FileLoader.new(batch_loader: Loader::HoldingLoader.for(umich_mon_backup.backup_path))
      loader.load(umich_mon_backup.backup_path)
      expect(umich_mon_backup.match_count).to eq affected_count

      # Remove first backupfile, write a new one and compare checksums
      FileUtils.rm(umich_mon_backup.backup_path)
      umich_mon_backup.write_backup_file
      second_checksum = `md5sum #{umich_mon_backup.backup_path}`

      expect(first_checksum).to eq second_checksum
    end
  end
end
