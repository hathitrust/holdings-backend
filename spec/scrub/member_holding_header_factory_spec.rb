# frozen_string_literal: true

require "scrub/member_holding_header_factory"
require "scrub/item_type_error"

RSpec.describe Scrub::MemberHoldingHeaderFactory do
  let(:mix) { "mix" }
  let(:mon) { "mon" }
  let(:spm) { "spm" }
  let(:mpm) { "mpm" }
  let(:ser) { "ser" }
  let(:failme) { "FAIL ME" }

  let(:min_ok_hed) { "oclc\tlocal_id" }

  def check_class(item_type, hed)
    Scrub::MemberHoldingHeaderFactory.for(item_type, hed)
  end

  it "returns the correct subclass" do
    expect(check_class(mix, min_ok_hed)).to be_a(Scrub::MixHoldingHeader)
    expect(check_class(mon, min_ok_hed)).to be_a(Scrub::MonHoldingHeader)
    expect(check_class(spm, min_ok_hed)).to be_a(Scrub::SpmHoldingHeader)
    expect(check_class(mpm, min_ok_hed)).to be_a(Scrub::MpmHoldingHeader)
    expect(check_class(ser, min_ok_hed)).to be_a(Scrub::SerHoldingHeader)
  end

  it "raises an error given an illegal item_type" do
    expect { check_class(failme, min_ok_hed) }.to raise_error(Scrub::ItemTypeError)
  end

  it "returns a col map (hash)" do
    mhh = described_class.for(mon, min_ok_hed)
    col_map = mhh.get_col_map
    expect(col_map.keys.size).to be(2)
    expect(col_map["oclc"]).to be(0)
    expect(col_map["local_id"]).to be(1)
  end

  it "tells you what the possible cols are for a given type" do
    mon_cols = described_class.for(spm, min_ok_hed).possible_cols
    expect(mon_cols.include?("oclc")).to be true
    expect(mon_cols.include?("enum_chron")).to be false

    mpm_cols = described_class.for(mpm, min_ok_hed).possible_cols
    expect(mpm_cols.include?("oclc")).to be true
    expect(mpm_cols.include?("enum_chron")).to be true
  end

  it "reports violations" do
    # none expected
    mhh = described_class.for(mon, min_ok_hed)
    expect(mhh.check_violations.empty?).to be(true)

    # some expected
    mhh = described_class.for(mon, failme)
    expect(mhh.check_violations.empty?).to be(false)
  end
end
