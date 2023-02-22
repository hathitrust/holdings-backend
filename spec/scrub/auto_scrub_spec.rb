# frozen_string_literal: true

require "scrub/autoscrub"
require "utils/line_counter"

RSpec.describe Scrub::AutoScrub do
  def test_file
    # Set up a minimal OK input file, which should result in success.
    test_file_path = "#{ENV["TEST_TMP"]}/testmember_mon_full_20201230_rspec.tsv"
    File.open(test_file_path, "w") do |f|
      f.puts("oclc\tlocal_id")
      f.puts("555\ti12345678")
    end

    test_file_path
  end

  let(:today_ymd) { Time.new.strftime("%F") }
  let(:scrubber) { described_class.new(test_file) }
  let(:out_struct) { scrubber.output_struct }

  it "does a scrub without raising anything" do
    expect { scrubber.run }.not_to raise_error
  end

  it "creates a set of directories handled by ScrubOutputStructure" do
    scrubber.run

    expect(Dir.exist?(out_struct.member_dir)).to be(true)
    expect(Dir.exist?(out_struct.member_log)).to be(true)
    expect(Dir.exist?(out_struct.member_output)).to be(true)
  end

  it "datestamps dirs with current date" do
    scrubber.run

    expect(out_struct.latest("output").to_path).to end_with today_ymd
  end

  it "puts files in the ready_to_load and log dirs" do
    scrubber.run

    expect(Dir.empty?(out_struct.member_ready_to_load)).to be(false)
    expect(Dir.empty?(out_struct.latest("log"))).to be(false)
  end

  it "doesn't put anything in the loaded dir" do
    scrubber.run

    expect(Dir.empty?(out_struct.member_loaded)).to be(true)
  end

  it "produces valid JSON" do
    scrubber.run

    latest_rtl = out_struct.member_ready_to_load.children.select do |file|
      file.match?(/testmember_mon_[0-9-]+.ndj/)
    end.max

    first_line = File.open(
      File.join(out_struct.member_ready_to_load.to_path, latest_rtl),
      &:readline
    )

    expect(JSON.parse(first_line)).to be_a(Hash)
  end

  it "ok with enum_chron in the header line" do
    mpm_scrubber = described_class.new(fixture("umich_mpm_full_20221118.tsv"))
    expect { mpm_scrubber.run }.not_to raise_error
    expect(mpm_scrubber.out_files.size).to eq 1
    expect(Utils::LineCounter.count_file_lines(mpm_scrubber.out_files.first)).to eq 3
  end

  it "raises if given a file with illegal utf sequence" do
    path = "#{ENV["TEST_TMP"]}/umich_mpm_full_20200101_badutf.tsv"
    FileUtils.cp(fixture("non_valid_utf8.txt"), path)
    scrubber = described_class.new(path)
    expect { scrubber.run }.to raise_error EncodingError
  end
end
