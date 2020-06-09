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

  describe "#merge" do
    let(:c1) { create(:cluster, ocns: [ocn1]) }
    let(:c2) { create(:cluster, ocns: [ocn2]) }
    let(:htitem1) { build(:ht_item, ocns: [ocn1]).to_hash }
    let(:htitem2) { build(:ht_item, ocns: [ocn2]).to_hash }

    it "still a cluster" do
      expect(c1.merge(c2).class).to eq(described_class)
    end

    it "combines ocns sets" do
      expect(c1.merge(c2).ocns).to eq([ocn1, ocn2])
    end

    it "combines ht_items" do
      c1.ht_items.create(htitem1)
      c2.ht_items.create(htitem2)
      expect(c1.merge(c2).ht_items.count).to eq(2)
    end

    it "combines and dedupes commitments" do
      c1.commitments.create(organization: "nypl")
      c2.commitments.create(organization: "nypl")
      c2.commitments.create(organization: "miu")
      expect(c1.merge(c2).commitments.count).to eq(2)
    end
  end

  describe "#merge_many" do
    let(:c1) { create(:cluster, ocns: [ocn1]) }
    let(:c2) { create(:cluster, ocns: [ocn2]) }

    it "combines multiple clusters" do
      c1
      c2
      expect(described_class.count).to eq(2)
      expect(described_class.merge_many([c1, c2]).ocns).to eq([ocn1, ocn2])
      expect(described_class.count).to eq(1)
    end
  end

  describe "#collect_ocns" do
    let(:ht) { build(:ht_item) }
    let(:holding) { build(:holding) }
    let(:resolution) { build(:ocn_resolution) }
    let(:cluster) { create(:cluster) }

    before(:each) do
      cluster.ht_items << ht
      cluster.holdings << holding
      cluster.ocn_resolutions << resolution
    end

    it "gathers all of the OCNs from it's embedded documents" do
      expect(cluster.collect_ocns).to include(*ht.ocns)
      expect(cluster.collect_ocns).to include(*holding.ocn)
      expect(cluster.collect_ocns).to include(*resolution.ocns)
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
end
