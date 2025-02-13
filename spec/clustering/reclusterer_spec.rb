# frozen_string_literal: true

require "spec_helper"
require "cluster"
require "clustering/cluster_commitment"
require "clustering/cluster_ht_item"
require "clustering/cluster_ocn_resolution"

RSpec.xdescribe Clustering::Reclusterer do
  let(:glue) { build(:ocn_resolution) }
  let(:ht_item) { build(:ht_item, ocns: [glue.variant]) }
  let(:holding) { build(:holding, ocn: glue.canonical) }
  let(:comm) { build(:commitment, ocn: glue.canonical) }

  context "when removing glue from Item/Holding/Commitment cluster" do
    before(:each) do
      Cluster.each(&:delete)
      Clustering::ClusterOCNResolution.new(glue).cluster
      Clustering::ClusterHtItem.new(ht_item).cluster
      Clustering::ClusterHolding.new(holding).cluster
      Clustering::ClusterCommitment.new(comm).cluster
    end

    it "splits the cluster into two" do
      expect(Cluster.count).to eq(1)
      Clustering::ClusterOCNResolution.new(glue).delete
      expect(Cluster.count).to eq(2)
    end

    it "moves ht_item, holding, and comm to new clusters" do
      Clustering::ClusterOCNResolution.new(glue).delete
      expect(Cluster.find_by(ocns: glue.variant).ht_items.count).to eq(1)
      expect(Cluster.find_by(ocns: glue.canonical).holdings.count).to eq(1)
      expect(Cluster.find_by(ocns: glue.canonical).commitments.count).to eq(1)
    end
  end

  context "when removing non-glue from cluster" do
    let(:nonglue) { build(:ocn_resolution, ocns: [glue.canonical, 666]) }

    before(:each) do
      Cluster.each(&:delete)
      Clustering::ClusterOCNResolution.new(glue).cluster
      Clustering::ClusterHtItem.new(ht_item).cluster
      Clustering::ClusterOCNResolution.new(nonglue).cluster
    end

    it "updates the cluster's OCNS" do
      # calls described_class.new(cluster).recluster
      Clustering::ClusterOCNResolution.new(nonglue).delete
      c = Cluster.first
      expect(c.ocns).to eq((glue.ocns + ht_item.ocns).flatten.uniq)
      expect(c.ocns).not_to include(666)
    end
  end

  describe "#needs_recluster?" do
    # TODO: These are bad tests that won't get full test coverage on their own because they overlap.
    # Test the private methods used by needs_recluster? ?
    before(:each) do
      Cluster.each(&:delete)
    end

    it "returns false if there is only one OCN" do
      cluster = Clustering::ClusterHolding.new(build(:holding)).cluster.tap(&:save)
      reclusterer = described_class.new(cluster)
      expect(reclusterer.needs_recluster?).to be false
    end

    it "returns false if it has an OCLC resolution covers both OCNS" do
      Clustering::ClusterOCNResolution.new(glue).cluster
      Clustering::ClusterHtItem.new(ht_item).cluster
      expect(Cluster.first.ocns).to eq(glue.ocns)
      expect(described_class.new(Cluster.first).needs_recluster?).to be false
    end

    it "returns false if it has an HTItem with the same OCNs as the cluster" do
      Clustering::ClusterHtItem.new(ht_item).cluster
      Clustering::ClusterHtItem.new(build(:ht_item, ocns: glue.ocns)).cluster
      expect(Cluster.first.ocns).to eq(glue.ocns)
      expect(described_class.new(Cluster.first).needs_recluster?).to be false
    end

    it "returns false if there is only one component" do
      cluster = Clustering::ClusterHtItem.new(build(:ht_item)).cluster.tap(&:save)
      reclusterer = described_class.new(cluster)
      expect(reclusterer.needs_recluster?).to be false
    end

    it "returns false if the OCNs are connected" do
      Clustering::ClusterHtItem.new(ht_item).cluster.tap(&:save)
      cluster = Clustering::ClusterHolding.new(build(:holding, ocn: ht_item.ocns.first)).cluster
      reclusterer = described_class.new(cluster)
      expect(reclusterer.needs_recluster?).to be false
    end
  end

  describe "#ocns_changed?" do
    before(:each) do
      Cluster.each(&:delete)
      Clustering::ClusterOCNResolution.new(glue).cluster
      Clustering::ClusterHtItem.new(build(:ht_item, ocns: [glue.ocns, 999].flatten)).cluster
      Clustering::ClusterHolding.new(holding).cluster
    end

    it "returns true if removed_ocns contains an OCN no longer found in clusterable_ocn_tuples" do
      cluster = Cluster.first
      reclusterer = described_class.new(cluster, [:not_in_cluster])
      expect(reclusterer.ocns_changed?).to be true
    end

    it "returns false if removed_ocns are all in other clusterable_ocn_tuples" do
      cluster = Cluster.first
      reclusterer = described_class.new(cluster, [glue.canonical, 999])
      expect(reclusterer.ocns_changed?).to be false
    end
  end
end
