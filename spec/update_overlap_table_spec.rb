# frozen_string_literal: true

require "spec_helper"
require "cluster_overlap"
require "clustering/cluster_holding"
require "clustering/cluster_ht_item"
require_relative "../bin/update_overlap_table"

RSpec.describe "update_overlap_table" do
  before(:each) do |_spec|
    h   = build(:holding)
    ht  = build(:ht_item, ocns: [h.ocn], billing_entity: "not_same_as_holding")
    ht2 = build(:ht_item, billing_entity: "not_same_as_holding")
    Cluster.each(&:delete)
    Clustering::ClusterHolding.new(h).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht2).cluster.tap(&:save)

    Services.register(:holdings_db) { HoldingsDB.connection }
    Services.holdings_db[:holdings_htitem_htmember].delete
  end

  describe "#overlap_table" do
    it "gets us the holdings_htitem_htmember table" do
      expect(overlap_table.count).to eq(0)
    end
  end

  describe "#upsert_cluster" do
    it "adds a new overlap to the table" do
      upsert_cluster(Cluster.first, Services.logger, Utils::Waypoint.new)
      expect(overlap_table.count).to eq(2)
      upsert_cluster(Cluster.last, Services.logger, Utils::Waypoint.new)
      expect(overlap_table.count).to eq(3)
    end

    it "updates an existing overlap in the table" do
      expect(overlap_table.count).to eq(0)
      cfirst = Cluster.first
      upsert_cluster(cfirst, Services.logger, Utils::Waypoint.new)
      expect(overlap_table.count).to eq(2)
      cfirst.holdings.each(&:delete)
      cfirst.save
      upsert_cluster(Cluster.first, Services.logger, Utils::Waypoint.new)
      expect(overlap_table.count).to eq(1)
    end
  end
end
