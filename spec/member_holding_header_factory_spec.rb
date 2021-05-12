# frozen_string_literal: true

require "member_holding_header_factory"
require "custom_errors"

RSpec.describe MemberHoldingHeaderFactory do
  let(:mon) { "mono" }
  let(:mul) { "multi" }
  let(:ser) { "serial" }
  let(:failme) { "FAIL ME" }

  let(:min_ok_hed) { "oclc\tlocal_id" }

  def check_class(item_type, hed)
    MemberHoldingHeaderFactory.new(item_type, hed).get_instance
  end

  it "returns the correct subclass" do
    expect(check_class(mon, min_ok_hed)).to be_a(MonoHoldingHeader)
    expect(check_class(mul, min_ok_hed)).to be_a(MultiHoldingHeader)
    expect(check_class(ser, min_ok_hed)).to be_a(SerialHoldingHeader)
  end

  it "raises an error given an illegal item_type" do
    expect { check_class(failme, min_ok_hed) }.to raise_error(ItemTypeError)
  end

  it "returns a col map (hash)" do
    mhh_fac = described_class.new(mon, min_ok_hed)
    mhh     = mhh_fac.get_instance
    col_map = mhh.get_col_map
    expect(col_map.keys.size).to be(2)
    expect(col_map["oclc"]).to be(0)
    expect(col_map["local_id"]).to be(1)
  end

  it "reports violations" do
    # none expected
    mhh_fac = described_class.new(mon, min_ok_hed)
    mhh     = mhh_fac.get_instance
    expect(mhh.check_violations.empty?).to be(true)

    # some expected
    mhh_fac = described_class.new(mon, failme)
    mhh     = mhh_fac.get_instance
    expect(mhh.check_violations.empty?).to be(false)
  end
end
