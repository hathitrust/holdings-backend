# frozen_string_literal: true

require "spec_helper"
require "reports/estimate"

RSpec.describe Reports::Estimate do
  include_context "with tables for holdings"

  let(:ht_allow) { build(:ht_item, rights: "pd") }
  let(:ht_deny) { build(:ht_item, rights: "ic") }
  let(:ocns) { [1, 2, ht_allow.ocns, ht_deny.ocns].flatten }
  let(:rpt) { described_class.new }

  before(:each) do
    Settings.target_cost = 20
    load_test_data(ht_allow, ht_deny)
  end

  describe "#cost_report" do
    it "creates an empty CR for target_cost reasons" do
      expect(rpt.cost_report.target_cost).to eq(20)
      expect(rpt.cost_report.cost_per_volume).to eq(10)
    end
  end

  describe "#find_matching_ocns" do
    it "sets num_items_pd" do
      rpt.find_matching_ocns(ocns)
      expect(rpt.num_items_pd).to eq(1)
    end

    it "sets num_items_ic" do
      rpt.find_matching_ocns(ocns)
      expect(rpt.num_items_ic).to eq(1)
    end

    it "compiles h_share_total" do
      rpt.find_matching_ocns(ocns)
      # the contributor gets the other half of the IC item
      expect(rpt.h_share_total).to eq(0.5)
    end

    it "counts only matching ocns" do
      rpt.find_matching_ocns(ocns)
      expect(rpt.num_ocns_matched).to eq(2)
    end

    it "counts items that match multiple OCNs only once" do
      multi_ocn_item = build(:ht_item, rights: "pd", ocns: [5, 6]).tap { |i| insert_htitem(i) }
      rpt.find_matching_ocns(multi_ocn_item.ocns)
      expect(rpt.num_items_pd).to eq(1)
    end

    it "counts icus items as pd" do
      icus_item = build(:ht_item, rights: "icus").tap { |i| insert_htitem(i) }
      rpt.find_matching_ocns(icus_item.ocns)
      expect(rpt.num_items_pd).to eq(1)
    end
  end

  describe "#total_estimate_ic_cost" do
    it "calculates total from h_share_total and cost_per_volume" do
      rpt.find_matching_ocns(ocns)
      expect(rpt.total_estimated_ic_cost).to eq(5)
    end
  end
end
