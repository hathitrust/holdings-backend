# frozen_string_literal: true

require "spec_helper"
require "serial_overlap"

RSpec.describe SerialOverlap do
  let(:c) { build(:cluster) }
  let(:ht) { build(:ht_item, :ser, ocns: c.ocns) }
  let(:ht2) { build(:ht_item, :ser, ocns: c.ocns, ht_bib_key: ht.ht_bib_key) }
  let(:h) { build(:holding, ocn: c.ocns.first, organization: "umich", status: "lm") }
  let(:h2) do
    build(:holding,
          ocn: c.ocns.first,
            organization: "umich",
            condition: "brt",
            enum_chron: "")
  end
  let(:h3) { build(:holding, ocn: c.ocns.first, organization: "smu") }

  before(:each) do
    Cluster.each(&:delete)
    c.save
    Clustering::ClusterHtItem.new(ht).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht2).cluster.tap(&:save)
    Clustering::ClusterHolding.new(h).cluster.tap(&:save)
    Clustering::ClusterHolding.new(h2).cluster.tap(&:save)
    Clustering::ClusterHolding.new(h3).cluster.tap(&:save)
    c.reload
  end

  describe "#copy_count" do
    it "is actually a serial" do
      expect(CalculateFormat.new(c).cluster_format).to eq("ser")
    end

    it "returns 1 if there is any match" do
      expect(described_class.new(c, h.organization, ht).copy_count).to eq(1)
    end

    it "returns 1 if billing_entity matches" do
      ht.update_attributes(billing_entity: "different_org")
      c.reload
      expect(described_class.new(c, "different_org", ht).copy_count).to eq(1)
    end
  end
end
