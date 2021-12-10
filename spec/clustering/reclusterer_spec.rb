# frozen_string_literal: true

require "spec_helper"
require "cluster"
require "clustering/cluster_commitment"
require "clustering/cluster_ht_item"
require "clustering/cluster_ocn_resolution"

RSpec.describe Clustering::Reclusterer do
  let(:glue) { build(:ocn_resolution) }
  let(:ht_item) { build(:ht_item, ocns: [glue.deprecated]) }
  let(:holding) { build(:holding, ocn: glue.resolved) }
  let(:comm) { build(:commitment, ocn: glue.resolved) }

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
      expect(Cluster.find_by(ocns: glue.deprecated).ht_items.count).to eq(1)
      expect(Cluster.find_by(ocns: glue.resolved).holdings.count).to eq(1)
      expect(Cluster.find_by(ocns: glue.resolved).commitments.count).to eq(1)
    end
  end
end
