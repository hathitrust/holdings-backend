# frozen_string_literal: true

require "cluster_overlap"

RSpec.describe ClusterOverlap do
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
    ClusterHtItem.new(spm).cluster.tap(&:save)
    ClusterHolding.new(holding).cluster.tap(&:save)
    ClusterHolding.new(holding2).cluster.tap(&:save)
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

  describe "#organization_in_cluster" do
    it "collects all of the organizations found in the cluster" do
      expect(described_class.new(Cluster.first).organizations_in_cluster).to \
        eq(["umich", "smu", "ucr"])
    end
  end
end
