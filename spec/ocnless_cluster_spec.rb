# frozen_string_literal: true

require "spec_helper"
require "cluster"

RSpec.describe OCNLessCluster do
  let(:bib_key1) { 1 }
  let(:c1) { described_class.new(bib_key: bib_key1) }
  let(:ht1) {
    build(
      :ht_item,
      ocns: [],
      ht_bib_key: bib_key1,
      enum_chron: "v.2",
      collection_code: "PU"
    )
  }
  let(:ht2) {
    build(
      :ht_item,
      ocns: [],
      ht_bib_key: bib_key1,
      enum_chron: "v.3",
      collection_code: "PU"
    )
  }

  include_context "with tables for holdings"

  describe "#initialize" do
    it "creates a new cluster" do
      expect(c1.class).to eq(described_class)
    end

    it "has an ocns field that is an empty Set" do
      expect(described_class.new(bib_key: bib_key1).ocns.class).to eq(Set)
      expect(described_class.new(bib_key: bib_key1).ocns.size).to eq(0)
    end
  end

  describe "#ht_items" do
    it "in a cluster with one bib_key, returns matching htitem" do
      insert_htitem(ht1)
      cluster_items = c1.ht_items
      expect(cluster_items.to_a.length).to eq(1)
      expect(cluster_items.first.item_id).to eq(ht1.item_id)
    end
  end

  describe "#holdings" do
    it "returns an empty Array" do
      expect(c1.holdings).to eq([])
    end
  end

  describe "#format" do
    it "has a format" do
      formats = ["spm", "mpm", "ser"]
      expect(formats).to include(c1.format)
    end
  end

  # Note: may need to revisit some of these for production overlap table
  describe "Precomputed fields" do
    before(:each) do
      insert_htitem ht1
      insert_htitem ht2
    end

    describe "#organizations_in_cluster" do
      it "collects all of the organizations found in the cluster" do
        expect(c1.organizations_in_cluster).to eq(["upenn"])
      end
    end

    describe "#item_enums" do
      it "collects all item enums in the cluster" do
        expect(c1.item_enums).to eq(["2", "3"])
      end
    end

    describe "#org_enums" do
      it "returns empty Array no matter the org" do
        expect(c1.org_enums["umich"]).to eq([])
        expect(c1.org_enums["upenn"]).to eq([])
        expect(c1.org_enums["an impossible key"]).to eq([])
      end
    end

    describe "#holding_enum_orgs" do
      it "returns empty Array no matter what" do
        expect(c1.holding_enum_orgs["1"]).to eq([])
        expect(c1.holding_enum_orgs["2"]).to eq([])
        expect(c1.holding_enum_orgs["an impossible key"]).to eq([])
      end
    end

    describe "#organizations_with_holdings_but_no_matches" do
      it "returns an empty Array" do
        expect(c1.organizations_with_holdings_but_no_matches).to eq([])
      end
    end

    describe "#holdings_by_org" do
      it "returns an empty Hash" do
        expect(c1.holdings_by_org).to eq({})
      end
    end

    counts_methods = %i[copy_counts brt_counts wd_counts lm_counts access_counts]
    counts_methods.each do |method|
      describe "##{method}" do
        it "returns 0 no matter the org" do
          expect(c1.send(method)["umich"]).to eq(0)
          expect(c1.send(method)["upenn"]).to eq(0)
          expect(c1.send(method)["an impossible key"]).to eq(0)
        end
      end
    end
  end
end
