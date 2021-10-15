# frozen_string_literal: true

require "spec_helper"
require "overlap/cluster_overlap"

RSpec.describe Overlap::ClusterOverlap do
  let(:c) { build(:cluster) }
  let(:spm) { build(:ht_item, ocns: c.ocns, enum_chron: "", billing_entity: "ucr") }
  let(:holding) { build(:holding, ocn: c.ocns.first, organization: "umich") }
  let(:holding2) do
    build(:holding,
          ocn: c.ocns.first,
            organization: "smu",
            condition: "brt")
  end

  before(:each) do
    Cluster.each(&:delete)
    c.save
    Clustering::ClusterHtItem.new(spm).cluster.tap(&:save)
    Clustering::ClusterHolding.new(holding).cluster.tap(&:save)
    Clustering::ClusterHolding.new(holding2).cluster.tap(&:save)
  end

  describe "#each" do
    it "provides an overlap for each ht_item" do
      overlap = described_class.new(Cluster.first, ["smu", "umich"])
      expect(overlap.each.count).to eq(2)
      overlap.each do |rec|
        expect(rec.to_hash[:volume_id]).to eq(spm.item_id)
        expect(rec.to_hash[:copy_count]).to eq(1)
      end
    end

    it "filters based on org" do
      overlap = described_class.new(Cluster.first, "smu")
      expect(overlap.each.count).to eq(1)
    end

    it "returns everything if we don't give it an org" do
      overlap = described_class.new(Cluster.first)
      expect(overlap.each.count).to eq(3)
    end
  end

  describe "Overlap::ClusterOverlap.matching_clusters" do
    let(:h) { build(:holding) }
    let(:ht) { build(:ht_item, ocns: [h.ocn], billing_entity: "not_same_as_holding") }
    let(:ht2) { build(:ht_item, billing_entity: "not_same_as_holding") }

    before(:each) do
      Cluster.each(&:delete)
      Clustering::ClusterHolding.new(h).cluster.tap(&:save)
      Clustering::ClusterHtItem.new(ht).cluster.tap(&:save)
      Clustering::ClusterHtItem.new(ht2).cluster.tap(&:save)
    end

    it "finds them all if org is nil" do
      expect(described_class.matching_clusters.count).to eq(2)
    end

    it "finds by holding" do
      expect(described_class.matching_clusters(h.organization).count).to eq(1)
    end

    it "finds by ht_item" do
      expect(described_class.matching_clusters(ht.billing_entity).count).to eq(2)
    end
  end
end
