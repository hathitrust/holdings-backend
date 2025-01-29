# frozen_string_literal: true

require "spec_helper"
require "reports/cost_report"
require "clustering/cluster_holding"
require "clustering/cluster_ht_item"

RSpec.describe Reports::CostReport do
  let(:cr) { described_class.new(cost: 10) }

  include_context "with cluster ocns table"
  include_context "with hathifiles table"
  describe "#compile_frequency_table" do
    it "ignores PD items" do
      pd_item = build(
        :ht_item,
        ocns: [1],
        access: "allow",
        rights: "pd",
        collection_code: "PU"
      )
      Cluster.create(ocns: [1])
      insert_htitem pd_item
      expect(cr.freq_table[:upenn][:spm]).to eq({})
    end

    it "counts OCN-less items" do
      item = build(
        :ht_item,
        :spm,
        ocns: [],
        access: "deny",
        rights: "ic",
        collection_code: "PU"
      )
      insert_htitem item
      expect(cr.freq_table[:upenn][:spm]).to eq({1 => 1})
    end
  end
end
