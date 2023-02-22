# frozen_string_literal: true

require "scrub/member_holding"
require "scrub/malformed_header_error"
require "scrub/col_val_error"
require "json"

RSpec.describe Scrub::MemberHolding do
  let(:test_data) { __dir__ + "/../testdata" }
  let(:ok_min_hed) { {"oclc" => 0, "local_id" => 1} }
  let(:ok_min_str) { "123\t456" }
  let(:ok_min_hold) { described_class.new(ok_min_hed) }

  let(:ok_max_hed) do
    {
      "oclc" => 0,
      "local_id" => 1,
      "status" => 2,
      "condition" => 3,
      "enum_chron" => 4,
      "govdoc" => 5
    }
  end
  let(:ok_max_str) { "123\tb456\tCH\tBRT\tv.1, 2020\t0" }
  let(:bad_max_str) { "123\tb456\tXX\tXXX\tv.1, 2020\t0" }
  let(:ok_max_hold) { described_class.new(ok_max_hed) }

  let(:bad_min_str) { "FAIL_ME\t456" }
  let(:bad_hed) { {"foo" => 0} }
  let(:bad_min_hold) { described_class.new(bad_hed) }

  let(:explode_ocn_str) { "1,2,3\t456" }

  it "creates a MemberHolding (min fields example)" do
    expect(ok_min_hold).to be_a(described_class)
  end

  it "creates a MemberHolding (max fields example)" do
    expect(ok_max_hold).to be_a(described_class)
  end

  it "parses a string (min example)" do
    expect(ok_min_hold.parse(ok_min_str)).to be(true)
  end

  it "parses a string (max example)" do
    expect(ok_max_hold.parse(ok_max_str)).to be(true)
  end

  it "sees no violations when parsing an ok string (min example)" do
    expect(ok_min_hold.violations).to eq([])
  end

  it "sees no violations when parsing an ok string (max example)" do
    expect(ok_max_hold.violations).to eq([])
  end

  it "produces valid json (min example)" do
    ok_min_hold.parse(ok_min_str)
    json_str = ok_min_hold.to_json
    expect(JSON.parse(json_str)).to be_a(Hash)
  end

  it "produces valid json (max example)" do
    ok_max_hold.parse(ok_max_str)
    json_str = ok_max_hold.to_json
    expect(JSON.parse(json_str)).to be_a(Hash)
  end

  it "raises an error if given a bad col type" do
    expect { ok_min_hold.parse("") }.to raise_error(Scrub::ColValError)
  end

  it "raises an error here too" do
    expect { bad_min_hold.parse(ok_min_str) }.to raise_error(Scrub::ColValError)
  end

  it "returns false if given a record with a bad ocn" do
    expect(ok_min_hold.parse(bad_min_str)).to be(false)
  end

  context "with known scrub logger" do
    let(:tmp_log) { "#{ENV["TEST_TMP"]}/member_holding_spec.log" }

    around(:each) do |example|
      # FIXME should log to string in RAM; duplicative of the around(:each, type: "loaded_file")
      # Log to file so we can look for a specific warning.
      old_logger = Services.scrub_logger
      begin
        Services.register(:scrub_logger) do
          Logger.new(tmp_log)
        end

        example.run
      ensure
        # Reset logger.
        Services.register(:scrub_logger) { old_logger }
        FileUtils.rm(tmp_log)
      end
    end

    it "warns but does not raise when setting a nil" do
      expect { ok_min_hold.set("oclc", nil) }.not_to raise_error
      expect(File.read(tmp_log)).to match(/col_val for col_type oclc is nil/)
    end
  end

  it "returns true if given a record with a bad status/condition etc" do
    # because those are not reason enough to reject the record, just the value
    # and should show up as warnings in the log
    expect(ok_max_hold.parse(bad_max_str)).to be(true)
  end

  it "explodes a line with multiple OCNs to a corresponding number of objects" do
    # 1 ocn, does not explode
    ok_min_hold.parse(ok_min_str)
    expect(ok_min_hold.explode_ocn.size).to be(1)

    # 3 ocns, explodes into 3
    ok_min_hold.parse(explode_ocn_str)
    expect(ok_min_hold.explode_ocn.size).to be(3)
  end
end
