# frozen_string_literal: true

require "ht_item_overlap"

RSpec.describe HtItemOverlap do
  let(:c) { build(:cluster) }
  let(:mpm) do
    build(:ht_item,
          ocns: c.ocns,
          enum_chron: "1",
          n_enum: "1",
          content_provider_code: "ucr")
  end
  let(:holding) do
    build(:holding,
          ocn: c.ocns.first,
          organization: "umich",
          enum_chron: "1",
          n_enum: "1")
  end
  let(:holding2) do
    build(:holding,
          ocn: c.ocns.first,
            organization: "smu",
            enum_chron: "1",
            n_enum: "1")
  end
  let(:non_match_holding) do
    build(:holding,
          ocn: c.ocns.first,
        organization: "stanford",
        enum_chron: "2",
        n_enum: "2")
  end

  before(:each) do
    Cluster.each(&:delete)
    c.save
    ClusterHtItem.new(mpm).cluster.tap(&:save)
    ClusterHolding.new(holding).cluster.tap(&:save)
    ClusterHolding.new(holding2).cluster.tap(&:save)
    ClusterHolding.new(non_match_holding).cluster.tap(&:save)
  end

  describe "#organizations_with_holdings" do
    it "returns all organizations that overlap with an item" do
      c.reload
      overlap = described_class.new(c.ht_items.first)
      expect(overlap.organizations_with_holdings.count).to eq(3)
    end

    it "does not include non-matching organizations" do
      c.reload
      overlap = described_class.new(c.ht_items.first)
      expect(overlap.organizations_with_holdings).not_to include("stanford")
    end

    it "only returns unique organizations" do
      ClusterHolding.new(holding).cluster.tap(&:save)
      c.reload
      expect(CalculateFormat.new(c).cluster_format).to eq("mpm")
      overlap = described_class.new(c.ht_items.first)
      expect(overlap.organizations_with_holdings.count).to eq(3)
    end
  end

  describe "#h_share" do
    it "returns ratio of organizations" do
      c.reload
      overlap = described_class.new(c.ht_items.first)
      expect(overlap.h_share("umich")).to eq(1.0 / 3)
    end

    it "returns 0 if not held" do
      c.reload
      overlap = described_class.new(c.ht_items.first)
      expect(overlap.h_share("stanford")).to eq(0)
    end
  end
end
