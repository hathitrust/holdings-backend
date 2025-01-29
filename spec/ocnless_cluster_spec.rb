# frozen_string_literal: true

require "spec_helper"
require "cluster"
require "clustering/cluster_ht_item"

RSpec.describe OCNLessCluster do
  let(:bib_key1) { 1 }
  let(:c1) { described_class.new(bib_key: bib_key1) }
  let(:ht) { build(:ht_item).to_hash }

  include_context "with cluster ocns table"

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
    include_context "with hathifiles table"

    it "in a cluster with one bib_key, returns matching htitem" do
      htitem = build(
        :ht_item,
        ocns: [],
        ht_bib_key: bib_key1,
        access: "allow",
        rights: "pd",
        collection_code: "PU"
      )
      insert_htitem(htitem)
      cluster_items = c1.ht_items
      expect(cluster_items.to_a.length).to eq(1)
      expect(cluster_items.first.item_id).to eq(htitem.item_id)
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

  # Not clear yet how to set up the scaffolding to test the methods we want to keep
  describe "Precomputed fields" do
    include_context "with hathifiles table"
    let(:ht1) {
      build(
        :ht_item,
        ocns: [],
        ht_bib_key: bib_key1,
        #enum_chron: "v.3",
        #FIXME: Auto-normalization is disabled? Re-enable when possible
        n_enum: "3",
        collection_code: "PU"
      )
    }

    before(:each) do
      insert_htitem ht1
    end

    describe "#organizations_in_cluster" do
      it "collects all of the organizations found in the cluster" do
        expect(c1.organizations_in_cluster).to eq(["upenn"])
      end
    end

    describe "#item_enums" do
      xit "collects all item enums in the cluster" do
        expect(c1.item_enums).to eq(["3"])
      end
    end

    describe "#org_enums" do
      it "maps orgs to their enums" do
        expect(c1.org_enums["umich"]).to eq([])
        expect(c1.org_enums["smu"]).to eq([])
        expect(c1.org_enums["an impossible key"]).to eq([])
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
          expect(c1.send(method)["smu"]).to eq(0)
          expect(c1.send(method)["an impossible key"]).to eq(0)
        end
      end
    end
  end
end
