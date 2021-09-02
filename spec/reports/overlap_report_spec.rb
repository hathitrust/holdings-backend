# frozen_string_literal: true

require "spec_helper"
require "clustering/cluster_ht_item"
require "clustering/cluster_holding"
require "reports/overlap_report"

RSpec.describe "overlap_report" do
  let(:h) { build(:holding) }
  let(:ht) { build(:ht_item, :spm, ocns: [h.ocn], billing_entity: "not_same_as_holding") }
  let(:ht2) { build(:ht_item, :spm, billing_entity: "not_same_as_holding") }

  before(:each) do
    Cluster.each(&:delete)
    Clustering::ClusterHolding.new(h).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht2).cluster.tap(&:save)
  end

  describe "run" do
    it "generates the correct report for the holding org" do
      h2 = h.dup
      h2.condition = "BRT"
      Cluster.first.add_holdings(h2).tap(&:save)
      cid = Cluster.first._id
      expect do
        Reports::OverlapReport.new(h.organization).run
      end.to output(
        "#{cid}\t#{cid}\t#{ht.item_id}\t#{ht.n_enum}\t#{h.organization}\t2\t1\t0\t0\t1\n"
      ).to_stdout
    end

    it "generates the correct report for the billing entity" do
      cluster1 = Cluster.first
      cluster2 = Cluster.find_by(ocns: ht2.ocns)
      cid1 = cluster1._id
      cid2 = cluster2._id
      expect do
        Reports::OverlapReport.new("not_same_as_holding").run
      end.to output(
        %(#{cid1}\t#{cid1}\t#{ht.item_id}\t#{ht.n_enum}\tnot_same_as_holding\t1\t0\t0\t0\t0
#{cid2}\t#{cid2}\t#{ht2.item_id}\t#{ht2.n_enum}\tnot_same_as_holding\t1\t0\t0\t0\t0\n)
      ).to_stdout
    end
  end
end
