# frozen_string_literal: true

require "clustering/cluster_commitment"
require "reports/uncommitted_holdings"
require "spec_helper"

RSpec.describe Reports::UncommittedHoldings do
  let(:report_all) { described_class.new(all: true) }

  let(:ocn1) { 5 }
  let(:org1) { "umich" }
  let(:loc1) { "i123" }
  let(:ht_spm1) { build(:ht_item, :spm, ocns: [ocn1]) }
  let(:hol1) { build(:holding, ocn: ocn1, local_id: loc1, organization: org1) }
  let(:com1) { build(:commitment, ocn: ocn1, local_id: loc1, organization: org1) }

  let(:ocn2) { 6 }
  let(:org2) { "smu" }
  let(:loc2) { "i456" }
  let(:ht_spm2) { build(:ht_item, :spm, ocns: [ocn2]) }
  let(:hol2) { build(:holding, ocn: ocn2, local_id: loc2, organization: org2) }
  let(:com2) { build(:commitment, ocn: ocn2, local_id: loc2, organization: org2) }

  let(:mpm) { build(:ht_item, :mpm, ocns: [ocn1]) }
  let(:ser) { build(:ht_item, :ser, ocns: [ocn1]) }

  # Runs report, returns records. Run, report. Run!
  def run_report(report)
    returned_records = []
    report.run do |record|
      returned_records << record
    end
    returned_records
  end

  before(:each) do
    Cluster.collection.find.delete_many
  end

  describe "basic stuff" do
    it "has a header" do
      expect(report_all.header).to eq ["organization", "oclc_sym", "ocn", "local_id"]
    end
    it "returns an array of UncommittedHoldingsRecord" do
      cluster_tap_save [hol1, ht_spm1]
      results = run_report(report_all)
      expect(results).to be_a Array
      expect(results.first).to be_a Reports::UncommittedHoldingsRecord
      expect(results.first.ocn).to eq ocn1
    end
    it "does nothing if :noop=true" do
      cluster_tap_save [hol1, ht_spm1]
      results = run_report(described_class.new(all: true, noop: true))
      expect(results).to be_a Array
      expect(results.size).to eq 0
    end
    it "raises error if given empty criteria" do
      expect { described_class.new }.to raise_exception(ArgumentError)
    end
  end

  describe "all search" do
    it "can search the whole collection" do
      cluster_tap_save [hol1, ht_spm1, hol2, ht_spm2]
      expect(run_report(report_all).size).to eq 2
    end
    it "returns holdings for clusters that do not have commitments" do
      cluster_tap_save [hol1, ht_spm1]
      expect(run_report(report_all).size).to eq 1
    end
    it "returns no holdings from clusters that have active commitments" do
      cluster_tap_save [hol1, ht_spm1, com1]
      expect(run_report(report_all).size).to eq 0
    end
    it "returns holdings from clusters that have deprecated commitments" do
      com1.deprecate(status: "E")
      cluster_tap_save [hol1, ht_spm1, com1]
      expect(run_report(report_all).size).to eq 1
    end
    it "ignores mpm" do
      cluster_tap_save [hol1, mpm]
      expect(run_report(report_all).size).to eq 0
    end
    it "ignores ser" do
      cluster_tap_save [hol1, ser]
      expect(run_report(report_all).size).to eq 0
    end
  end

  describe "search by OCN(s)" do
    it "can search by a single OCN" do
      cluster_tap_save [hol1, ht_spm1, hol2, ht_spm2]
      results = run_report(described_class.new(ocn: [ocn1]))
      expect(results.size).to eq 1
      expect(results.first.ocn).to eq ocn1
    end
    it "can search by multiple OCNs" do
      cluster_tap_save [hol1, ht_spm1, hol2, ht_spm2]
      results = run_report(described_class.new(ocn: [ocn1, ocn2]))
      expect(results.size).to eq 2
    end
  end

  describe "search by organization(s)" do
    it "can search by a single organization" do
      cluster_tap_save [hol1, ht_spm1, hol2, ht_spm2]
      results = run_report(described_class.new(organization: [org1]))
      expect(results.size).to eq 1
      expect(results.first.organization).to eq org1
    end
    it "can search by multiple organizations" do
      cluster_tap_save [hol1, ht_spm1, hol2, ht_spm2]
      results = run_report(described_class.new(organization: [org1, org2]))
      expect(results.size).to eq 2
    end
  end

  describe "combined search" do
    it "can do a combined search using both a single OCN and a single organization" do
      cluster_tap_save [hol1, ht_spm1, hol2, ht_spm2]
      results = run_report(described_class.new(ocn: [ocn1], organization: [org1]))
      expect(results.size).to eq 1
      expect(results.first.ocn).to eq ocn1
    end
    it "can do a combined search using both multiple OCNs and multiple organizations" do
      cluster_tap_save [hol1, ht_spm1, hol2, ht_spm2]
      results = run_report(described_class.new(ocn: [ocn1, ocn2], organization: [org1, org2]))
      expect(results.size).to eq 2
    end
  end
end
