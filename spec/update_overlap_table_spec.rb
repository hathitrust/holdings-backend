# frozen_string_literal: true

require "spec_helper"
require "cluster_overlap"
require "clustering/cluster_holding"
require "clustering/cluster_ht_item"
require_relative "../bin/update_overlap_table"

RSpec.describe "update_overlap_table" do
  before(:each) do
    Cluster.each(&:delete)
    Services.register(:holdings_db) { HoldingsDB.connection }
    Services.holdings_db[:holdings_htitem_htmember].delete
  end

  let(:holding) { build(:holding) }
  let(:ht_item)  { build(:ht_item, ocns: [holding.ocn], billing_entity: "not_same_as_holding") }
  let(:ht_item2) { build(:ht_item, billing_entity: "not_same_as_holding") }
  let(:ht_item3) { build(:ht_item) }

  let!(:no_htitem_cluster) { create(:cluster) }
  let!(:holding_htitem_cluster) do
    Clustering::ClusterHolding.new(holding).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht_item).cluster.tap(&:save)
  end

  let!(:no_holdings_cluster) do
    Clustering::ClusterHtItem.new(ht_item2).cluster.tap(&:save)
  end

  let!(:old_cluster) do
    Clustering::ClusterHtItem.new(ht_item3).cluster.tap do |c|
      c.save

      # Manually backdate last_modified
      Cluster.collection.update_one({ ocns: c.ocns[0] },
                                    "$set" => { last_modified: Date.today - 7 })
    end
  end

  describe "#overlap_table" do
    it "gets us the holdings_htitem_htmember table" do
      expect(overlap_table.count).to eq(0)
    end
  end

  describe "#upsert_cluster" do
    it "adds a new overlap to the table" do
      expect(overlap_table.count).to eq(0)
      upsert_cluster(holding_htitem_cluster, Services.logger, Utils::Waypoint.new)
      expect(overlap_table.count).to eq(2)
      upsert_cluster(no_holdings_cluster, Services.logger, Utils::Waypoint.new)
      expect(overlap_table.count).to eq(3)
    end

    it "updates an existing overlap in the table" do
      expect(overlap_table.count).to eq(0)
      cluster = Cluster.for_ocns(holding_htitem_cluster.ocns).first
      upsert_cluster(cluster, Services.logger, Utils::Waypoint.new)
      expect(overlap_table.count).to eq(2)
      cluster.holdings.each(&:delete)
      cluster.save

      cluster = Cluster.for_ocns(holding_htitem_cluster.ocns).first
      upsert_cluster(cluster, Services.logger, Utils::Waypoint.new)
      expect(overlap_table.count).to eq(1)
    end
  end

  describe "#clusters_modified_since" do
    it "returns only modified clusters with htitems" do
      expect(clusters_modified_since(Date.today - 1.5))
        .to contain_exactly(holding_htitem_cluster, no_holdings_cluster)
    end
  end
end
