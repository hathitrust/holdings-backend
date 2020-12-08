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
      ClusterHolding.new(h1).cluster.tap(&:save)
      ClusterHolding.new(h2).cluster.tap(&:save)
      ClusterHtItem.new(ht1).cluster.tap(&:save)
    end

    describe "#organizations_in_cluster" do
      it "collects all of the organizations found in the cluster" do
        expect(described_class.first.organizations_in_cluster).to \
          eq([h1.organization, h2.organization, ht1.billing_entity].uniq)
      end
    end

    describe "#item_enum_chron_orgs" do
      it "has an item enumchrons orgs" do
        c = described_class.first
        expect(c.item_enum_chron_orgs[ht1.n_enum]).to eq([ht1.billing_entity])
      end

      it "returns an empty set if none found" do
        c = described_class.first
        expect(c.item_enum_chron_orgs["invalid_enum"]).to eq([])
      end
    end

    describe "#holding_enum_chron_orgs" do
      it "maps enumchrons to member holdings" do
        c = described_class.first
        expect(c.holding_enum_chron_orgs[h1.n_enum]).to eq([h1.organization])
      end
    end
  end
end
