# frozen_string_literal: true

require "spec_helper"
require "overlap"

RSpec.describe Overlap do
  let(:c) { build(:cluster) }
  let(:ht) { build(:ht_item, ocns: c.ocns, bib_fmt: "ser", enum_chron: "") }
  let(:h) { build(:holding, ocn: c.ocns.first, organization: "umich", status: "lm") }
  let(:h2) do
    build(:holding,
          ocn: c.ocns.first,
            organization: "umich",
            condition: "brt",
            enum_chron: "V.1")
  end
  let(:h3) { build(:holding, ocn: c.ocns.first, organization: "smu") }

  before(:each) do
    Cluster.each(&:delete)
    c.save
    ClusterHtItem.new(ht).cluster.tap(&:save)
    ClusterHolding.new(h).cluster.tap(&:save)
    ClusterHolding.new(h2).cluster.tap(&:save)
    ClusterHolding.new(h3).cluster.tap(&:save)
    c.reload
  end

  describe "#to_hash" do
    it "returns a mostly empty hash" do
      overlap_hash = described_class.new(c, h.organization, ht).to_hash
      expect(overlap_hash).to eq(cluster_id: c._id.to_s,
          volume_id: ht.item_id,
          member_id: h.organization,
          copy_count: "",
          brt_count: "",
          wd_count: "",
          lm_count: "",
          access_count: "")
    end
  end

  describe "#matching_holdings" do
    it "finds all matching holdings for an org" do
      overlap = described_class.new(c, "umich", ht)
      expect(overlap.matching_holdings.pluck(:organization)).to eq(["umich", "umich"])
    end
  end
end
