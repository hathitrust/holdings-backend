# frozen_string_literal: true

require "spec_helper"
require "cluster"
require "cluster_ht_item"
require "large_clusters"
require "large_cluster_error"

RSpec.describe LargeClusters do
  let(:mock_data) { [1_759_445, 8_878_489].to_set }
  let(:large_clusters) { described_class.new(mock_data) }

  before(:each) do
    Cluster.each(&:delete)
  end

  describe "#ocns" do
    it "has the list of ocns provided" do
      expect(large_clusters.ocns).to include(1_759_445)
    end
  end

  describe "#load_large_clusters" do
    it "pulls the list of ocns from the configured file" do
      `echo "1001117803" > #{Settings.large_cluster_ocns}`
      large_clusters = described_class.new
      expect(large_clusters.ocns).to include(1_001_117_803)
    end
  end

  describe "reclustering of large clusters" do
    # A change in the OCNs of ht_items' OCNs or ocn_resolutions can result in a recluster.
    # Reclustering a "large cluster" will result in a cluster with incomplete holdings.
    let(:ht1) { build(:ht_item, ocns: [large_clusters.ocns.first]) }
    let(:ht2) { build(:ht_item, ocns: [large_clusters.ocns.first, 1]) }

    it "does not raise an error when performing a simple update" do
      ClusterHtItem.new(ht1).cluster
      ClusterHtItem.new(ht2).cluster
      ht2.ocns << 1
      expect { ClusterHtItem.new(ht2).cluster }.not_to raise_error
    end

    it "raises a LargeClusterError when reclustering a large cluster" do
      ClusterHtItem.new(ht1).cluster
      ClusterHtItem.new(ht2).cluster
      expect(Cluster.first.ht_items.count).to eq(2)
      # ht2 previously glued large_clusters.ocns.first and 1 together, so
      # changing to just 1 requires reclustering
      ht2.ocns = [1]
      expect do
        ClusterHtItem.new(ht2).cluster
      end.to raise_exception(LargeClusterError)
    end
  end

  describe "merging of large clusters" do
    # Merging a non-"large cluster" into a "large cluster" means future holdings will be deduped.
    # This is expected behavior, but worth tracking
    let(:ht1) { build(:ht_item, ocns: [large_clusters.ocns.first]) }

    before(:each) do
      Cluster.each(&:delete)
      ClusterHtItem.new(ht1).cluster
      # @orig_stderr = $stderr
      # $stderr = StringIO.new
    end

    it "warns when merging non-large with large clusters" do
      ht2 = build(:ht_item, ocns: [1])
      ClusterHtItem.new(ht2).cluster
      expect(Cluster.count).to eq(2)
      glue = build(:ht_item, ocns: [1, large_clusters.ocns.first])
      expect { ClusterHtItem.new(glue).cluster }.to \
        output("Merging into a large cluster. OCNs: [#{large_clusters.ocns.first}] and [1]\n")
        .to_stderr
      expect(Cluster.count).to eq(1)
    end

    it "is silent when merging 2 large clusters" do
      ht2 = build(:ht_item, ocns: [large_clusters.ocns.to_a.last])
      ClusterHtItem.new(ht2).cluster
      expect(Cluster.count).to eq(2)
      glue = build(:ht_item, ocns: [large_clusters.ocns.to_a.last, large_clusters.ocns.first])

      expect { ClusterHtItem.new(glue).cluster }.not_to output(/Merging/).to_stderr
      expect(Cluster.count).to eq(1)
    end
  end
end
