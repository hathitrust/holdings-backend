# frozen_string_literal: true

require "spec_helper"
require "cluster_ht_item"
RSpec.describe ClusterHtItem do
  let(:item) { build(:ht_item) }
  let(:item2) { build(:ht_item, ocns: ocns) }
  let(:ocns) { item.ocns }
  let(:batch) { [item, item2] }
  let(:empty_cluster) { create(:cluster, ocns: ocns) }
  let(:cluster_with_item) { create(:cluster, ocns: ocns, ht_items: [item]) }
  let(:no_ocn) { build(:ht_item, ocns: []) }

  before(:each) do
    Cluster.each(&:delete)
  end

  describe "#initialize" do
    it "accepts a single HTItem" do
      expect(described_class.new(item)).not_to be nil
    end

    it "accepts multiple HTItems as an array" do
      expect(described_class.new(batch)).not_to be nil
    end

    it "accepts multiple HTItems as direct arguments" do
      expect(described_class.new(item, item2)).not_to be nil
    end

    it "raises ArgumentError with two HTItems with different single OCNs" do
      expect do
        described_class.new([item, build(:ht_item)])
      end.to raise_exception(ArgumentError)
    end

    it "raises ArgumentError with two HTItems with different multiple OCNs" do
      expect do
        described_class.new([
          build(:ht_item, ocns: [1, 2]),
          build(:ht_item, ocns: [1, 3])
        ])
      end.to raise_exception(ArgumentError)
    end

    it "raises ArgumentError with two HTItems without an OCN" do
      expect do
        described_class.new([
          build(:ht_item, ocns: []),
          build(:ht_item, ocns: [])
        ])
      end.to raise_exception(ArgumentError)
    end
  end

  describe "#cluster" do
    it "adds multiple htitems to the cluster" do
      cluster = described_class.new(batch).cluster
      expect(cluster.ht_items.to_a.size).to eq(2)
    end

    it "first looks in the cluster it has for the htitem to update" do
      # ocn hasn't changed, so htitem should be in the initial cluster we got and
      # we shouldn't have to go fish
      cluster_with_item.save
      expect(Cluster).not_to receive(:with_ht_item)

      update_item = build(:ht_item, item_id: item.item_id, ocns: item.ocns)
      described_class.new(update_item).cluster
    end

    it "adds an HT Item to an existing cluster" do
      empty_cluster.save
      cluster = described_class.new(item).cluster
      expect(cluster.ht_items.first._parent.id).to eq(empty_cluster.id)
      expect(cluster.ht_items.to_a.size).to eq(1)
      expect(Cluster.each.to_a.size).to eq(1)
    end

    it "creates a new cluster if no match is found" do
      new_item = build(:ht_item)
      empty_cluster.save
      new_cluster = described_class.new(new_item).cluster
      expect(new_cluster.id).not_to eq(empty_cluster.id)
      expect(Cluster.each.to_a.size).to eq(2)
    end

    it "merges two or more clusters" do
      # first cluster with ht's ocns
      c = described_class.new(item).cluster
      # a second cluster with different ocns
      new_item = build(:ht_item)
      second_c = described_class.new(new_item).cluster
      # ht with ocns overlapping both
      overlapping_item = build(:ht_item, ocns: c.ocns+second_c.ocns)
      cluster = described_class.new(overlapping_item).cluster
      expect(Cluster.each.to_a.size).to eq(1)
      expect(cluster.ht_items.to_a.size).to eq(3)
    end

    it "cluster has its embed's ocns" do
      empty_cluster.save
      item.ocns << rand(1_000_000)
      cluster = described_class.new(item).cluster
      expect(cluster.ocns).to eq(item.ocns)
    end

    it "creates a new cluster for an OCNless Item" do
      cluster = described_class.new(no_ocn).cluster
      expect(cluster.ht_items.to_a.first.item_id).to eq(no_ocn.item_id)
    end

    it "cluster without OCN contains OCNless Item" do
      cluster = described_class.new(no_ocn).cluster
      expect(cluster.ht_items.to_a.first).to eq(no_ocn)
      expect(Cluster.each.to_a.first.ht_items.to_a.first).to eq(no_ocn)
    end

    it "creates a new cluster for multiple OCNless Items" do
      no_ocn2 = build(:ht_item, ocns: [])
      cluster = described_class.new(no_ocn).cluster
      cluster2 = described_class.new(no_ocn2).cluster
      expect(cluster).not_to eq(cluster2)
      expect(Cluster.each.to_a.size).to eq(2)
    end

    context "with HT2 as an update to HT" do
      let(:update_item) { build(:ht_item, item_id: item.item_id) }

      it "removes the old cluster" do
        first = described_class.new(item).cluster
        described_class.new(update_item).cluster
        expect(Cluster.each.to_a.size).to eq(1)
        new_cluster = Cluster.each.to_a.first
        expect(new_cluster).not_to eq(first)
        expect(new_cluster.ht_items.first).to eq(update_item)
      end
    end

    context "with HT2 with the same OCNS as HT" do
      let(:update_item) { build(:ht_item, item_id: item.item_id, ocns: item.ocns) }

      it "only updates the HT Item" do
        first = described_class.new(item).cluster
        updated = described_class.new(update_item).cluster
        expect(first).to eq(updated)
        expect(
          Cluster.each.to_a.first.ht_items.first.to_hash
        ).to eq(update_item.to_hash)
      end
    end

    it "reclusters an HTItem that gains an OCN" do
      ocnless_cluster = described_class.new(no_ocn).cluster
      ocnless_cluster.save
      empty_cluster.save
      expect(Cluster.each.to_a.size).to eq(2)
      updated_item = build(:ht_item, item_id: no_ocn.item_id, ocns: empty_cluster.ocns)
      described_class.new(updated_item).cluster
      expect(Cluster.each.to_a.size).to eq(1)
    end

    it "can add an HTItem to a cluster with a concordance rule" do
      resolution = build(:ocn_resolution)
      htitem = build(:ht_item, ocns: [resolution.deprecated])
      create(:cluster, ocns: resolution.ocns, ocn_resolutions: [resolution])
      c = described_class.new(htitem).cluster
      expect(c.valid?).to be true
    end
  end

  describe "#move" do
    let(:c2) { create(:cluster) }

    before(:each) do
      Cluster.each(&:delete)
      empty_cluster.save
    end

    it "moves an HT Item from one cluster to another" do
      cluster = described_class.new(item).cluster
      expect(cluster.ht_items.to_a.size).to eq(1)
      described_class.new(item).move(c2)
      expect(cluster.ht_items.to_a.size).to eq(0)
      expect(c2.ht_items.to_a.size).to eq(1)
    end

    it "won't move multiple htitems" do
      expect { described_class.new(batch).move(c2) }.to raise_exception(ArgumentError)
    end
  end

  describe "#delete" do
    let(:item2) { build(:ht_item, ocns: item.ocns) }

    before(:each) do
      Cluster.each(&:delete)
      empty_cluster.save
    end

    it "removes the cluster if it's only that htitem" do
      described_class.new(item).cluster
      expect(Cluster.each.to_a.size).to eq(1)
      described_class.new(item).delete
      expect(Cluster.each.to_a.size).to eq(0)
    end

    it "creates a new cluster without the ht_item" do
      described_class.new(item).cluster
      cluster = described_class.new(item2).cluster
      expect(cluster.ht_items.to_a.size).to eq(2)
      described_class.new(item).delete
      expect(Cluster.each.to_a.first.ht_items.to_a.size).to eq(1)
      expect(Cluster.each.to_a.first).not_to eq(cluster)
    end

    it "won't delete multiple items" do
      expect { described_class.new(batch).delete }.to raise_exception(ArgumentError)
    end
  end
end
