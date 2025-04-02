# frozen_string_literal: true

require "spec_helper"
require "reports/estimate"

RSpec.describe Reports::Estimate do
  include_context "with tables for holdings"

  let(:ht_allow) { build(:ht_item, rights: "pd") }
  let(:ht_deny) { build(:ht_item, rights: "ic") }
  let(:ocns) { [1, 2, ht_allow.ocns, ht_deny.ocns].flatten }
  let(:report) { described_class.new }

  # two records; one with a PD item, one with an IC item
  let(:test_records) { fixture("records_for_estimate.ndj") }

  before(:each) do
    Settings.target_cost = 20
    load_test_data(ht_allow, ht_deny)
  end

  describe "#cost_report" do
    it "creates an empty CR for target_cost reasons" do
      expect(report.cost_report.target_cost).to eq(20)
      expect(report.cost_report.cost_per_volume).to eq(10)
    end
  end

  describe "#dump_solr_records" do
    include_context "with mocked solr response"

    it "searches for each ocn" do
      # solr response has nothing in it;
      # should raise exception if we did some other query
      mock_solr_oclc_search(solr_response_for,
        filter: /oclc_search:\(#{ocns.join(" ")}\)/)

      report.dump_solr_records(ocns)
    end

    it "only writes each record once" do
      # create an htitem with two ocns
      ht_item = build(:ht_item, ocns: [1, 2])

      # query for only one of those OCNs at a time
      report = described_class.new(solr_query_size: 1)

      mock_solr_oclc_search(solr_response_for(ht_item), filter: /oclc_search:\(1\)/)
      mock_solr_oclc_search(solr_response_for(ht_item), filter: /oclc_search:\(2\)/)

      report.dump_solr_records([1, 2])

      # we should only see the catalog record once
      expect(File.open(report.allrecords_ndj).count).to eq(1)
    end

    it "counts only matching ocns" do
      mock_solr_oclc_search(solr_response_for(ht_allow, ht_deny))
      report.dump_solr_records(ocns)
      expect(report.num_ocns_matched).to eq(2)
    end
  end

  describe "#find_matching_ocns" do
    it "sets num_items_pd" do
      report.find_matching_ocns(test_records)
      expect(report.num_items_pd).to eq(1)
    end

    it "sets num_items_ic" do
      report.find_matching_ocns(test_records)
      expect(report.num_items_ic).to eq(1)
    end

    it "compiles h_share_total" do
      report.find_matching_ocns(test_records)
      # the contributor gets the other half of the IC item
      expect(report.h_share_total).to eq(0.5)
    end

    it "counts icus items as pd" do
      report.find_matching_ocns(fixture("icus_item.ndj"))
      expect(report.num_items_pd).to eq(1)
    end
  end

  describe "#total_estimate_ic_cost" do
    it "calculates total from h_share_total and cost_per_volume" do
      report.find_matching_ocns(test_records)
      expect(report.total_estimated_ic_cost).to eq(5)
    end
  end
end
