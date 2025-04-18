# frozen_string_literal: true

require "spec_helper"
require "scrub/record_counter"

RSpec.describe Scrub::RecordCounter do
  include_context "with tables for holdings"

  let(:org) { "umich" }
  let(:item_type) { "spm" }
  let(:rc) { described_class.new(org, item_type) }
  let(:loaded_file) {
    File.join(rc.struct.member_loaded, "#{org}_#{item_type}_2020-01-01.ndj")
  }
  let(:ready_file) {
    File.join(rc.struct.member_ready_to_load, "#{org}_#{item_type}_2021-01-01.ndj")
  }
  let(:hundo) { 100 }
  let(:small_diff) { (Settings.scrub_line_count_diff_max * 100) - 1 }

  # Write a testfile with a certain number of { "ocn": i } ndjs.
  def testfile(lines:, file:)
    File.open(file, "w") do |f|
      1.upto(lines) do |i|
        f.puts({"ocn" => i}.to_json)
      end
    end
  end

  # Write a testfile with array as basis for { "ocn": x } ndjs.
  def array_to_testfile(array:, file:)
    File.open(file, "w") do |f|
      array.each do |i|
        f.puts({"ocn" => i}.to_json)
      end
    end
  end

  describe "#initialize" do
    it "requires required args" do
      expect { described_class.new }.to raise_error ArgumentError
    end
    it "raises ArgumentError if missing any important settings" do
      org_setting = Settings.scrub_line_count_diff_max
      Settings.scrub_line_count_diff_max = nil
      expect { described_class.new(org, item_type) }.to raise_error ArgumentError
      Settings.scrub_line_count_diff_max = org_setting
    end
  end

  context "count methods" do
    describe "#count_loaded & #count_ready" do
      it "count_loaded empty == 0" do
        expect(rc.count_loaded).to eq 0
      end
      it "count_loaded 1 == 1" do
        testfile(lines: 1, file: loaded_file)
        expect(rc.count_loaded).to eq 1
      end
      it "count_ready empty == 0" do
        expect(rc.count_ready).to eq 0
      end
      it "count_ready 1 == 1" do
        testfile(lines: 1, file: ready_file)
        expect(rc.count_ready).to eq 1
      end
      it "counts each duplicate line" do
        duplicate_count = 5
        array_to_testfile(array: [1] * duplicate_count, file: ready_file)
        expect(rc.count_ready).to eq duplicate_count
      end
      it "dedupes ocns" do
        ocn_count = 5
        # make 3 copies of each ocn from 1..5
        array_to_testfile(array: (1..ocn_count).to_a * 3, file: ready_file)
        # expect 5, not 15
        expect(rc.count_ready_ocns).to eq ocn_count
      end
    end

    describe "#count_loaded_ocns & #count_ready_ocns" do
      it "count_loaded_ocns empty == 0" do
        expect(rc.count_loaded_ocns).to eq 0
      end
      it "count_loaded_ocns 1 == 1" do
        ocn_count = 3
        testfile(lines: ocn_count, file: loaded_file)
        expect(rc.count_loaded_ocns).to eq ocn_count
      end
      it "count_ready_ocns empty == 0" do
        expect(rc.count_ready_ocns).to eq 0
      end
      it "count_ready_ocns 1 == 1" do
        ocn_count = 3
        testfile(lines: ocn_count, file: ready_file)
        expect(rc.count_ready_ocns).to eq ocn_count
      end
    end
  end

  context "diff methods" do
    describe "line_diff" do
      it "reports the line difference as an absolute percentage" do
        testfile(lines: 1, file: ready_file)
        testfile(lines: 2, file: loaded_file)
        expect(rc.line_diff).to eq 0.5
        # percentage is absolute, i.e. we don't get -0.5 if we flip the counts
        testfile(lines: 2, file: ready_file)
        testfile(lines: 1, file: loaded_file)
        expect(rc.line_diff).to eq 0.5
      end
    end

    describe "ocn_diff" do
      it "reports the ocn difference as an absolute percentage" do
        testfile(lines: 1, file: ready_file)
        testfile(lines: 2, file: loaded_file)
        expect(rc.ocn_diff).to eq 0.5
        # percentage is absolute, i.e. we don't get -0.5 if we flip the counts
        testfile(lines: 2, file: ready_file)
        testfile(lines: 1, file: loaded_file)
        expect(rc.ocn_diff).to eq 0.5
      end
    end

    describe "#acceptable_diff?" do
      it "is not acceptable if there are no files to load" do
        expect(rc.acceptable_diff?).to be false
      end
      it "is acceptable if there are files to load and nothing was loaded before" do
        testfile(lines: hundo, file: ready_file)
        expect(rc.acceptable_diff?).to be true
      end
      it "is acceptable if the line counts are the same" do
        testfile(lines: hundo, file: ready_file)
        testfile(lines: hundo, file: loaded_file)
        expect(rc.acceptable_diff?).to be true
      end
      it "is acceptable if the line counts are same-ish" do
        testfile(lines: hundo, file: ready_file)
        testfile(lines: hundo - small_diff, file: loaded_file)
        expect(rc.acceptable_diff?).to be true
      end
      it "is not acceptable if the diff is greater than Settings.scrub_line_count_diff_max" do
        testfile(lines: hundo, file: ready_file)
        testfile(lines: hundo / small_diff, file: loaded_file)
        expect(rc.acceptable_diff?).to be false
      end
      it "is not acceptable if the diff is greater than scrub_line_count_diff_max, reversed" do
        testfile(lines: hundo / small_diff, file: ready_file)
        testfile(lines: hundo, file: loaded_file)
        expect(rc.acceptable_diff?).to be false
      end
      it "is unacceptable if either line_diff or ocn_diff are unacceptable" do
        array_to_testfile(array: (1..100).to_a, file: loaded_file) # file w/ 100 distinct ocns
        array_to_testfile(array: [1] * 100, file: ready_file) # file w/ 100 identical ocns
        expect(rc.acceptable_diff?).to be false
        expect(rc.line_diff).to eq 0.0
        expect(rc.ocn_diff).to eq 0.99
        expect(rc.message).to include(match(/Distinct OCN diff too great/))
      end
    end
  end

  context "integration test" do
    require "data_sources/directory_locator"
    require "scrub/scrub_output_structure"
    require "scrub/scrub_runner"

    # In sequence:
    # 1) Try loading 1 small file.
    # 2) Try loading a significantly larger file  on top of that and get failure.
    # 3) Try loading it again with --force and get success.
    let(:loadfile_small) { fixture("umich_mon_full_20220101_ocndiff1.tsv") }
    let(:small_count) { 6 }
    let(:loadfile_large) { fixture("umich_mon_full_20220102_ocndiff2.tsv") }
    let(:large_count) { 13 }
    let(:local) { DataSources::DirectoryLocator.new(Settings.local_member_data, org) }
    let(:remote) { DataSources::DirectoryLocator.new(Settings.remote_member_data, org) }

    scrub_options = {"force_holding_loader_cleanup_test" => true}
    scrub_force_options = scrub_options.merge({"force" => true})

    def get_loaded
      Clusterable::Holding.for_organization(org)
    end

    it "will reject a large diff, unless --force is applied" do
      local.ensure!
      remote.ensure!

      # Load a small file, expect a small db count.
      FileUtils.copy(loadfile_small, remote.holdings_current)
      scrub_runner = Scrub::ScrubRunner.new(org, scrub_options)
      scrub_runner.run
      expect(get_loaded.count).to eq small_count

      # Load a large file on top of that, expect db count to remain small.
      FileUtils.copy(loadfile_large, remote.holdings_current)
      scrub_runner = Scrub::ScrubRunner.new(org, scrub_options)
      scrub_runner.run
      expect(get_loaded.count).to eq small_count
      # Check that the scrub log file contains the specific warning we are looking for
      log_dir_path = Scrub::ScrubOutputStructure.new(org).latest("log").path
      log_file = Dir.new(log_dir_path).children.first
      log_file_path = File.join(log_dir_path, log_file)
      log_file_contents = File.read(log_file_path)
      expect(log_file_contents).to match(/Line diff too great/)
      expect(log_file_contents).to match(/Distinct OCN diff too great/)
      expect(log_file_contents).to match(/This file will not be loaded/)

      # Load large file again with --force and expect db count to be large.
      FileUtils.copy(loadfile_large, remote.holdings_current)
      scrub_runner = Scrub::ScrubRunner.new(org, scrub_force_options)
      scrub_runner.run
      expect(get_loaded.count).to eq large_count
    end
  end
end
