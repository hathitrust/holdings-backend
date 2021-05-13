# frozen_string_literal: true

require "scrub_output_structure"
require "custom_errors"

RSpec.describe ScrubOutputStructure do
  let(:test) { described_class.new("test") }

  after(:each) do
    FileUtils.remove_dir(described_class.new("test").member_dir)
  end

  it "makes a new dir structure" do
    expect(test.member_id).to eq("test")
    expect(test.member_log).to be_a(Dir)
    expect(test.member_output).to be_a(Dir)
  end

  it "produces valid json" do
    expect(test.to_json).to be_a(String)
    expect(JSON.parse(test.to_json)).to be_a(Hash)
  end

  it "creates a datestamped subdir for log or output" do
    expect(Dir.exist?(test.date_subdir!("log"))).to be(true)
    expect(Dir.exist?(test.date_subdir!("output"))).to be(true)
  end

  it "does not let you create any other subdirs" do
    expect { test.date_subdir!("foo") }.to raise_error(StandardError)
  end

  it "gives you the latest-datest subdir (by string sort)" do
    test.date_subdir!("log", "2021-01-01")
    test.date_subdir!("log", "9999-12-30")
    test.date_subdir!("log", "1999-01-01")
    expect(test.latest("log").path.split("/").last).to eq("9999-12-30")
  end

  it "only lets you pick a date that matches d4-d2-d2" do
    # should work
    expect(test.date_subdir!("log", "2021-01-01")).to be_a(Dir)
    # don't look
    expect(test.date_subdir!("log", "2020-50-50")).to be_a(Dir)
    # should fail
    expect { test.date_subdir!("log", "JAN 1ST LAST YEAR") }.to raise_error(StandardError)
  end
end
