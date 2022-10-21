# frozen_string_literal: true

require "spec_helper"
require "scrub/record_counter"

RSpec.describe Scrub::RecordCounter do
  let(:org) { "umich" }
  let(:item_type) { "mono" }
  let(:rc) { described_class.new(org, item_type) }
  let(:loaded_file) {
    File.join(rc.struct.member_loaded, "#{org}_#{item_type}_2020-01-01.ndj")
  }
  let(:ready_file) {
    File.join(rc.struct.member_ready_to_load, "#{org}_#{item_type}_2021-01-01.ndj")
  }
  let(:hundo) { 100 }
  let(:small_diff) { (Settings.scrub_line_count_diff_max * 100) - 1 }
  before(:each) do
    FileUtils.rm_rf("/tmp/scrub_data/#{org}/")
  end
  def put_x_lines_in_file(x, file)
    File.open(file, "w") do |f|
      1.upto(x) do |i|
        f.puts(i)
      end
    end
  end
  context "#initialize" do
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
  context "#count_loaded & #count_ready" do
    it "count_loaded empty == 0" do
      expect(rc.count_loaded).to eq 0
    end
    it "count_loaded 1 == 1" do
      put_x_lines_in_file(1, loaded_file)
      expect(rc.count_loaded).to eq 1
    end
    it "count_ready empty == 0" do
      expect(rc.count_ready).to eq 0
    end
    it "count_ready 1 == 1" do
      put_x_lines_in_file(1, ready_file)
      expect(rc.count_ready).to eq 1
    end
  end
  context "#acceptable_diff?" do
    it "is not acceptable if there are no files to load" do
      expect(rc.acceptable_diff?).to be false
    end
    it "is acceptable if there are files to load and nothing was loaded before" do
      put_x_lines_in_file(hundo, ready_file)
      expect(rc.acceptable_diff?).to be true
    end
    it "is acceptable if the line counts are the same" do
      put_x_lines_in_file(hundo, ready_file)
      put_x_lines_in_file(hundo, loaded_file)
      expect(rc.acceptable_diff?).to be true
    end
    it "is acceptable if the line counts are same-ish" do
      put_x_lines_in_file(hundo, ready_file)
      put_x_lines_in_file(hundo - small_diff, loaded_file)
      expect(rc.acceptable_diff?).to be true
    end
    it "is not acceptable if the diff is greater than Settings.scrub_line_count_diff_max" do
      put_x_lines_in_file(hundo, ready_file)
      put_x_lines_in_file(hundo / small_diff, loaded_file)
      expect(rc.acceptable_diff?).to be false
    end
    it "is not acceptable if the diff is greater than scrub_line_count_diff_max, reversed" do
      put_x_lines_in_file(hundo / small_diff, ready_file)
      put_x_lines_in_file(hundo, loaded_file)
      expect(rc.acceptable_diff?).to be false
    end
  end
end
