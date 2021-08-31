# frozen_string_literal: true

require "spec_helper"
require "report/estimate_ic"
require "clustering/cluster_ht_item"

RSpec.describe Report::EstimateIC do
  let(:ht_allow) { build(:ht_item, access: "allow") }
  let(:ht_deny) { build(:ht_item, access: "deny") }
  let(:ocns) { [1, 2, ht_allow.ocns, ht_deny.ocns].flatten }
  let(:rpt) { described_class.new(ocns) }

  before(:each) do
    Settings.target_cost = 20
    Cluster.each(&:delete)
    Clustering::ClusterHtItem.new(ht_allow).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht_deny).cluster.tap(&:save)
  end

  describe "#cost_report" do
    it "creates an empty CR for target_cost reasons" do
      expect(rpt.cost_report.target_cost).to eq(20)
      expect(rpt.cost_report.cost_per_volume).to eq(10)
    end
  end

  describe "#run" do
    it "sets num_items_pd" do
      rpt.run
      expect(rpt.num_items_pd).to eq(1)
    end

    it "sets num_items_ic" do
      rpt.run
      expect(rpt.num_items_ic).to eq(1)
    end

    it "compiles h_share_total" do
      rpt.run
      # the contributor gets the other half of the IC item
      expect(rpt.h_share_total).to eq(0.5)
    end
  end

  describe "#total_estimate_ic_cost" do
    it "calculates total from h_share_total and cost_per_volume" do
      rpt.run
      expect(rpt.total_estimated_ic_cost).to eq(5)
    end
  end
end
