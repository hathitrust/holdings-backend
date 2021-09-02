# frozen_string_literal: true

require "spec_helper"
require "report/member_counts_report"
require "report/cost_report"
require_relative "../../bin/reports/compile_member_counts_report"

RSpec.describe "MemberCountsReport" do
  let(:mokk_members) { ["umich", "utexas", "smu"] }

  let(:mcr) do
    Report::MemberCountsReport.new("/dev/null", mokk_members)
  end

  let(:rows) { mcr.run.rows }

  let(:labels) { ["total_loaded", "distinct_ocns", "matching_volumes"] }
  let(:formats) { ["mono", "multi", "serial"] }

  let(:cluster) { build(:cluster) }
  let(:ht_item) { build(:ht_item) }

  let(:cluster2) { build(:cluster) }
  let(:ht_item2) { build(:ht_item) }

  before(:each) do
    Cluster.each(&:delete)
  end

  describe "basic format" do
    it "makes rows for all members given" do
      expect(rows.size).to eq(3)
      expect(
        rows.key?("umich")  &&
        rows.key?("utexas") &&
        rows.key?("smu")
      ).to be(true)
    end

    it "makes rows consisting of hashes of labels" do
      expect(rows["umich"]).to be_a(Report::MemberCountsRow)
      expect(rows["umich"].counts).to be_a(Hash)
      expect(rows["umich"].counts.keys).to eq(labels)
    end

    it "... consisting of hashes of formats" do
      expect(
        labels.map {|x| rows["umich"].counts[x].class }
      ).to eq([Hash, Hash, Hash])

      expect(
        labels.map {|x| rows["umich"].counts[x].keys }
      ).to eq([formats, formats, formats])
    end
  end

  describe "total_loaded" do
    it "starts empty" do
      expect(rows["umich"].counts["total_loaded"].values.sum).to eq(0)
    end

    it "increments by one" do
      # For each holding with the same ocn we add, expect total loaded to go up
      1.upto(3).each do |i|
        holding = build(
          :holding,
          ocn: ht_item.ocns.first,
          organization: "umich",
          mono_multi_serial: "mono"
        )
        Clustering::ClusterHolding.new(holding).cluster.tap(&:save)
        expect(mcr.run.rows["umich"].counts["total_loaded"]["mono"]).to eq(i)
      end
    end
  end

  describe "distinct_ocns" do
    def item_holding_cluster(item)
      holding = build(
        :holding,
        ocn: item.ocns.first,
        organization: "umich",
        mono_multi_serial: "mono"
      )
      Clustering::ClusterHtItem.new(item).cluster.tap(&:save)
      Clustering::ClusterHolding.new(holding).cluster.tap(&:save)
    end

    it "starts empty" do
      expect(rows["umich"].counts["distinct_ocns"]["mono"]).to eq(0)
    end

    it "don't increment distinct ocn if adding identical holdings" do
      # Add 1 holding (matching a HT item), expect count to be 1
      item_holding_cluster(ht_item)
      expect(
        rows["umich"].counts["distinct_ocns"]["mono"] *
        rows["umich"].counts["total_loaded"]["mono"]
      ).to eq(1)

      # Add 1 of the same holding, expect distinct count to remain 1 as total_loaded goes up
      item_holding_cluster(ht_item)
      rows = mcr.run.rows
      expect(rows["umich"].counts["distinct_ocns"]["mono"]).to eq(1)
      expect(rows["umich"].counts["total_loaded"]["mono"]).to eq(2)
    end

    it "do increments distinct ocn if adding different ocns" do
      # Add 2 holdings (matching a HT item), with different ocns, expect distinct_ocns == 2
      item_holding_cluster(ht_item)
      item_holding_cluster(ht_item2)
      expect(ht_item.ocns.first).not_to eq(ht_item2.ocns.first)

      rows = mcr.run.rows
      expect(rows["umich"].counts["distinct_ocns"]["mono"]).to eq(2)
    end
  end

  describe "matching_volumes" do
    it "does nothing unless given a freq file" do
      expect(rows["umich"].counts["matching_volumes"].values.sum).to be(0)
    end

    it "reads a freq file and populates report accordingly" do
      freq_file = "spec/fixtures/freq.txt"
      rows2 = Report::MemberCountsReport.new(freq_file, mokk_members).run.rows
      expect(rows2["umich"].counts["matching_volumes"]["mono"]).to eq(1)
      expect(rows2["umich"].counts["matching_volumes"]["multi"]).to eq(2)
      expect(rows2["umich"].counts["matching_volumes"]["serial"]).to eq(1)
    end
  end
end
