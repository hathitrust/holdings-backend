# frozen_string_literal: true

require "spec_helper"
require "autoscrub"

RSpec.describe AutoScrub do
  # Set up a minimal OK input file, which should result in success.
  test_file_path = "/tmp/testmember_mono_full_20201230_rspec.tsv"
  test_file = File.open(test_file_path, "w")
  test_file.puts("oclc\tlocal_id")
  test_file.puts("555\ti12345678")
  test_file.close

  today_ymd  = Time.new.strftime("%F")
  scrubber   = described_class.new(test_file_path)
  out_struct = scrubber.output_struct

  it "does a scrub without raising anything" do
    expect { scrubber.run }.not_to raise_error
  end

  it "created a set of directories handled by ScrubOutputStructure" do
    expect(Dir.exist?(out_struct.member_dir)).to be(true)
    expect(Dir.exist?(out_struct.member_log)).to be(true)
    expect(Dir.exist?(out_struct.member_output)).to be(true)
  end

  it "datestamped dirs with current date" do
    expect(out_struct.latest("output").to_path).to end_with today_ymd
  end

  it "put files in the ready_to_load and log dirs" do
    expect(Dir.empty?(out_struct.member_ready_to_load)).to be(false)
    expect(Dir.empty?(out_struct.latest("log"))).to be(false)
  end

  it "didn't put anything in the loaded dir" do
    expect(Dir.empty?(out_struct.member_loaded)).to be(true)
  end

  it "produced valid JSON" do
    latest_rtl = out_struct.member_ready_to_load.children.select do |file|
      file.match?(/testmember_mono_[0-9-]+.ndj/)
    end.max

    first_line = File.open(
      File.join(out_struct.member_ready_to_load.to_path, latest_rtl),
      &:readline
    )

    expect(JSON.parse(first_line)).to be_a(Hash)
  end

  it "cleans up after the last test" do
    FileUtils.remove_dir(out_struct.member_dir)
    expect(Dir.exist?(out_struct.member_dir)).to be(false)
  end
end
