# frozen_string_literal: true

require "cluster_ht_item"
RSpec.describe ClusterHtItem do
  let(:ht) { build(:ht_item) }
  let(:c) { create(:cluster, ocns: ht.ocns) }

  describe "#cluster" do
    before(:each) do
      Cluster.each(&:delete)
    end

    it "adds an HT Item to an existing cluster" do
      c.save
      cluster = described_class.new(ht).cluster
      expect(cluster.ht_items.first._parent.id).to eq(c.id)
      expect(cluster.ht_items.to_a.size).to eq(1)
      expect(Cluster.each.to_a.size).to eq(1)
    end

    it "creates a new cluster if no match is found" do
      c.save
      new_cluster = described_class.new(build(:ht_item)).cluster
      expect(new_cluster.id).not_to eq(c.id)
      expect(Cluster.each.to_a.size).to eq(2)
    end

    it "merges two or more clusters" do
      # first cluster with ht's ocns
      c = described_class.new(ht).cluster
      # a second cluster with different ocns
      second_c = described_class.new(build(:ht_item)).cluster
      # ht with ocns overlapping both
      overlapping_ht = build(:ht_item, ocns: c.ocns+second_c.ocns)
      cluster = described_class.new(overlapping_ht).cluster
      expect(Cluster.each.to_a.size).to eq(1)
      expect(cluster.ht_items.to_a.size).to eq(3)
    end

    it "cluster has it's embed's ocns" do
      c.save
      ht.ocns << rand(1_000_000)
      cluster = described_class.new(ht).cluster
      expect(cluster.ocns).to eq(ht.ocns)
    end
  end

  describe "#move" do
    let(:c2) { create(:cluster) }

    before(:each) do
      Cluster.each(&:delete)
      c.save
    end

    it "moves an HT Item from one cluster to another" do
      cluster = described_class.new(ht).cluster
      expect(cluster.ht_items.to_a.size).to eq(1)
      described_class.new(ht).move(c2)
      expect(cluster.ht_items.to_a.size).to eq(0)
      expect(c2.ht_items.to_a.size).to eq(1)
    end
  end

  describe "#delete" do
    let(:ht2) { build(:ht_item, ocns: ht.ocns) }

    before(:each) do
      Cluster.each(&:delete)
      c.save
    end

    it "removes the cluster if it's only that htitem" do
      described_class.new(ht).cluster
      expect(Cluster.each.to_a.size).to eq(1)
      described_class.new(ht).delete
      expect(Cluster.each.to_a.size).to eq(0)
    end

    it "creates a new cluster without the ht_item" do
      described_class.new(ht).cluster
      cluster = described_class.new(ht2).cluster
      expect(cluster.ht_items.to_a.size).to eq(2)
      described_class.new(ht).delete
      expect(Cluster.each.to_a.first.ht_items.to_a.size).to eq(1)
      expect(Cluster.each.to_a.first).not_to eq(cluster)
    end
  end

  describe "#update" do
    context "with HT2 as an update to HT" do
      let(:ht2) { build(:ht_item, item_id: ht.item_id) }

      before(:each) do
        Cluster.each(&:delete)
      end

      it "removes the old cluster" do
        first = described_class.new(ht).cluster
        described_class.new(ht2).update
        expect(Cluster.each.to_a.size).to eq(1)
        new_cluster = Cluster.each.to_a.first
        expect(new_cluster).not_to eq(first)
        expect(new_cluster.ht_items.first).to eq(ht2)
      end
    end

    context "with HT2 with the same OCNS as HT" do
      let(:ht2) { build(:ht_item, item_id: ht.item_id, ocns: ht.ocns) }

      before(:each) do
        Cluster.each(&:delete)
      end

      it "only updates the HT Item" do
        first = described_class.new(ht).cluster
        updated = described_class.new(ht2).update
        expect(first).to eq(updated)
        expect(
          Cluster.each.to_a.first.ht_items.first.to_hash
        ).to eq(ht2.to_hash)
      end
    end
  end
end
