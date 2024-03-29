# frozen_string_literal: true

require "spec_helper"
require "cluster"

RSpec.describe Cluster do
  let(:ocn1) { 5 }
  let(:ocn2) { 6 }
  let(:ht) { build(:ht_item).to_hash }

  before(:each) do
    described_class.create_indexes
    described_class.collection.find.delete_many
  end

  describe "#initialize" do
    it "creates a new cluster" do
      expect(described_class.new(ocns: [ocn1]).class).to eq(described_class)
    end

    it "has an ocns field that is Array" do
      expect(described_class.new(ocns: [ocn1]).ocns.class).to eq(Array)
    end

    it "has an ocns field with members that are Integers" do
      expect(described_class.new(ocns: [ocn1]).ocns.first.class).to eq(Integer)
    end

    it "validates the ocns field is numeric" do
      expect(described_class.new(ocns: ["a"])).not_to be_valid
    end

    it "validates that it has all HT Item ocns" do
      c = described_class.new(ocns: [ocn1])
      c.save
      c.ht_items.create(ht)
      c.ht_items.first.ocns << rand(1_000_000)
      c.save
      expect(c.errors.messages[:ocns]).to include("must contain all ocns")
    end

    it "prevents duplicate HT Items" do
      c = described_class.new(ocns: [ocn1])
      c.save
      c.ht_items.create(ht)
      c2 = described_class.new(ocns: [ocn2])
      c2.save
      expect { c2.ht_items.create(ht) }.to \
        raise_error(Mongo::Error::OperationFailure, /ht_items.item_id_1 dup/)
    end
  end

  describe "#format" do
    let(:c1) { create(:cluster) }

    it "has a format" do
      formats = ["spm", "mpm", "ser"]
      expect(formats).to include(c1.format)
    end
  end

  describe "#last_modified" do
    let(:c1) { build(:cluster) }

    it "doesn't have last_modified if unsaved" do
      expect(c1.last_modified).to be_nil
    end

    it "has last_modified if it is saved" do
      now = Time.now.utc
      c1.save
      expect(c1.last_modified).to be > now
    end

    it "updates last_modified when it is saved" do
      c1.save
      first_timestamp = c1.last_modified
      c1.save
      second_timestamp = c1.last_modified
      expect(first_timestamp).to be < second_timestamp
    end
  end

  describe "#save" do
    let(:c1) { build(:cluster, ocns: [ocn1, ocn2]) }
    let(:c2) { build(:cluster, ocns: [ocn2]) }

    it "can't save them both" do
      c1.save
      expect { c2.save }.to \
        raise_error(Mongo::Error::OperationFailure, /duplicate key error/)
    end

    it "saves to the database" do
      c1.save
      expect(described_class.count).to eq(1)
      expect(described_class.where(ocns: ocn1).count).to eq(1)
    end
  end

  describe "Precomputed fields" do
    let(:h1) { build(:holding, ocn: ocn1, enum_chron: "1") }
    let(:h2) { build(:holding, ocn: ocn1, enum_chron: "2", organization: h1.organization) }
    let(:ht1) { build(:ht_item, ocns: [ocn1], enum_chron: "3", billing_entity: h1.organization) }

    before(:each) do
      Clustering::ClusterHolding.new(h1).cluster.tap(&:save)
      Clustering::ClusterHolding.new(h2).cluster.tap(&:save)
      Clustering::ClusterHtItem.new(ht1).cluster.tap(&:save)
      Clustering::ClusterHolding.new(build(:holding, ocn: ocn2, organization: "umich"))
        .cluster.tap(&:save)
      Clustering::ClusterHolding.new(build(:holding, ocn: ocn2, organization: "umich"))
        .cluster.tap(&:save)
      Clustering::ClusterHolding.new(build(:holding, ocn: ocn2, organization: "smu"))
        .cluster.tap(&:save)
    end

    describe "#organizations_in_cluster" do
      it "collects all of the organizations found in the cluster" do
        expect(described_class.first.organizations_in_cluster).to \
          eq([h1.organization, h2.organization, ht1.billing_entity].uniq)
      end
    end

    describe "#item_enums" do
      it "collects all item enums in the cluster" do
        c = described_class.first
        expect(c.item_enums).to eq(["3"])
      end
    end

    describe "#holding_enum_orgs" do
      it "maps enums to member holdings" do
        c = described_class.first
        expect(c.holding_enum_orgs[h1.n_enum]).to eq([h1.organization])
      end
    end

    describe "#org_enums" do
      it "maps orgs to their enums" do
        c = described_class.first
        expect(c.org_enums[h1.organization]).to eq([h1.n_enum, h2.n_enum])
      end
    end

    describe "#organizations_with_holdings_but_no_matches" do
      it "is a list of orgs in the cluster that don't match anything" do
        h3 = build(:holding, ocn: ocn1, enum_chron: "4", organization: "ualberta")
        Clustering::ClusterHolding.new(h3).cluster.tap(&:save)
        c = described_class.first
        expect(c.organizations_with_holdings_but_no_matches).to include("ualberta")
      end

      it "does not include orgs that do have a match" do
        matching_holding = build(:holding, ocn: ocn1, enum_chron: "3")
        Clustering::ClusterHolding.new(matching_holding).cluster.tap(&:save)
        c = described_class.first
        expect(c.organizations_with_holdings_but_no_matches).not_to \
          include(matching_holding.organization)
      end

      it "DOES NOT include orgs that only have a billing entity match" do
        ht2 = build(:ht_item, ocns: [ocn1], enum_chron: "5", billing_entity: "ualberta")
        Clustering::ClusterHtItem.new(ht2).cluster.tap(&:save)
        c = described_class.first
        expect(c.organizations_with_holdings_but_no_matches).not_to include("ualberta")
        # but does if they have a non-matching holding
        h3 = build(:holding, ocn: ocn1, enum_chron: "6", organization: "ualberta")
        Clustering::ClusterHolding.new(h3).cluster.tap(&:save)
        c = described_class.where(ocns: ocn1).first
        expect(c.organizations_with_holdings_but_no_matches).to include("ualberta")
      end
    end

    describe "#holdings_by_org" do
      it "collates holdings by org" do
        c = described_class.where(ocns: ocn2).first
        expect(c.holdings_by_org["umich"].size).to eq(2)
        expect(c.holdings_by_org["smu"].size).to eq(1)
      end
    end

    describe "#copy_counts" do
      it "counts holdings per org" do
        c = described_class.where(ocns: ocn2).first
        expect(c.copy_counts["umich"]).to eq(2)
        expect(c.copy_counts["smu"]).to eq(1)
      end

      xit "cached counts should be invalidated when holdings/ht_items are changed" do
        c = described_class.where(ocns: ocn2).first
        expect(c.copy_counts["umich"]).to eq(2)
        c.holdings.map(&:delete)
        expect(c.holdings.size).to eq(0)
        expect(c.copy_counts["umich"]).to eq(0)
      end
    end
  end
end
