# frozen_string_literal: true

require "cluster_ht_item"
require_relative "../bin/export_overlap_report"

RSpec.describe "overlap_report" do
  let(:h) { build(:holding) }
  let(:ht) { build(:ht_item, ocns: [h.ocn], billing_entity: "not_same_as_holding") }
  let(:ht2) { build(:ht_item, billing_entity: "not_same_as_holding") }

  before(:each) do
    Cluster.each(&:delete)
    ClusterHolding.new(h).cluster.tap(&:save)
    ClusterHtItem.new(ht).cluster.tap(&:save)
    ClusterHtItem.new(ht2).cluster.tap(&:save)
  end

  describe "matching_clusters" do
    it "finds them all if org is nil" do
      expect(matching_clusters.count).to eq(2)
    end

    it "finds by holding" do
      expect(matching_clusters(h.organization).count).to eq(1)
    end

    it "finds by ht_item" do
      expect(matching_clusters(ht.billing_entity).count).to eq(2)
    end
  end
end
