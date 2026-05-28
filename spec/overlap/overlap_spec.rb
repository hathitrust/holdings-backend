# frozen_string_literal: true

require "spec_helper"
require "overlap/overlap"

RSpec.describe Overlap::Overlap do
  include_context "with tables for holdings"

  let(:ht_item) { build(:ht_item, :spm) }
  let(:holding) { build(:holding, ocn: ht_item.ocns.first, organization: "umich", status: "lm") }
  let(:holding2) do
    build(:holding,
      ocn: ht_item.ocns.first,
      organization: "umich",
      condition: "brt",
      enum_chron: "V.1")
  end
  let(:holding3) { build(:holding, ocn: ht_item.ocns.first, organization: "smu") }

  before(:each) do
    load_test_data(ht_item, holding, holding2, holding3)
  end

  describe "#matching_holdings" do
    it "finds all matching holdings for an org" do
      overlap = described_class.new("umich", ht_item)
      expect(overlap.matching_holdings.map(&:organization)).to eq(["umich", "umich"])
    end
  end
end
