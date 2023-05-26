# frozen_string_literal: true

require "spec_helper"
require "cluster"
require "clustering/cluster_ht_item"
require "data_sources/large_clusters"
require "large_cluster_error"
require "loader/holding_loader"
require "utils/line_counter"

RSpec.describe DataSources::LargeClusters do
  let(:mock_data) { [1_759_445, 8_878_489].to_set }
  let(:large_clusters) { described_class.new(mock_data) }
  let(:lrg_ocn) { large_clusters.ocns.first }
  let(:org1) { "umich" }
  let(:org2) { "smu" }

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

  describe "adding holdings to a LargeCluster via cluster_tap_save" do
    it "adding 2 hol from 1 org results in 1 hol (the first) on cluster" do
      # setup
      hol1 = build(:holding, ocn: lrg_ocn, organization: org1)
      hol2 = build(:holding, ocn: lrg_ocn, organization: org1)
      cluster_tap_save [hol1, hol2]
      cluster_holdings_uuids = Cluster.where(ocns: lrg_ocn).first.holdings.map(&:uuid)
      # execution
      expect(hol1.uuid == hol2.uuid).to be false
      expect(cluster_holdings_uuids.size).to eq 1
      expect(cluster_holdings_uuids).to eq [hol1.uuid]
    end
    it "adding 2 hol from 2 orgs results in 2 hol on cluster" do
      # setup
      hol1 = build(:holding, ocn: lrg_ocn, organization: org1)
      hol2 = build(:holding, ocn: lrg_ocn, organization: org2) # <<< org diff
      cluster_tap_save [hol1, hol2]
      cluster_holdings_uuids = Cluster.where(ocns: lrg_ocn).first.holdings.map(&:uuid)
      # execution
      expect(hol1.uuid == hol2.uuid).to be false
      expect(cluster_holdings_uuids.size).to eq 2
      expect(cluster_holdings_uuids).to eq [hol1.uuid, hol2.uuid]
    end
  end

  describe "loading holdings via holdingloader" do
    it "only adds one holding to a LargeCluster even if given many similar" do
      fixt = fixture("large_cluster.ndj") # 100 umich holdings for lrg_ocn
      batch = []
      batch_loader = Loader::HoldingLoaderNDJ.new

      cluster_tap_save [build(:ht_item, ocns: [lrg_ocn])]
      File.open(fixt, "r") do |f|
        f.each_line do |line|
          batch << batch_loader.item_from_line(line)
        end
      end
      Loader::HoldingLoader.new.load(batch)
      expect(Utils::LineCounter.new(fixt).count_lines).to eq 100
      expect(Cluster.where(ocns: lrg_ocn).first.holdings.size).to eq 1
    end
  end

  describe "reclustering of large clusters" do
    # A change in the OCNs of ht_items' OCNs or ocn_resolutions can result in a recluster.
    # Reclustering a "large cluster" will result in a cluster with incomplete holdings.
    let(:ht1) { build(:ht_item, ocns: [large_clusters.ocns.first]) }
    let(:ht2) { build(:ht_item, ocns: [large_clusters.ocns.first, 1]) }

    it "does not raise an error when performing a simple update" do
      Clustering::ClusterHtItem.new(ht1).cluster
      Clustering::ClusterHtItem.new(ht2).cluster
      ht2.ocns << 1
      expect { Clustering::ClusterHtItem.new(ht2).cluster }.not_to raise_error
    end

    it "raises a LargeClusterError when reclustering a large cluster" do
      Clustering::ClusterHtItem.new(ht1).cluster
      Clustering::ClusterHtItem.new(ht2).cluster
      expect(Cluster.first.ht_items.count).to eq(2)
      # ht2 previously glued large_clusters.ocns.first and 1 together, so
      # changing to just 1 requires reclustering
      ht2.ocns = [1]
      expect do
        Clustering::ClusterHtItem.new(ht2).cluster
      end.to raise_exception(LargeClusterError)
    end
  end

  describe "merging of large clusters" do
    # Merging a non-"large cluster" into a "large cluster" means future holdings will be deduped.
    # This is expected behavior, but worth tracking
    let(:ht1) { build(:ht_item, ocns: [large_clusters.ocns.first]) }

    before(:each) do
      Cluster.each(&:delete)
      Clustering::ClusterHtItem.new(ht1).cluster
      # @orig_stderr = $stderr
      # $stderr = StringIO.new
    end

    it "warns when merging non-large with large clusters" do
      ht2 = build(:ht_item, ocns: [1])
      Clustering::ClusterHtItem.new(ht2).cluster
      expect(Cluster.count).to eq(2)
      glue = build(:ht_item, ocns: [1, large_clusters.ocns.first])
      expect { Clustering::ClusterHtItem.new(glue).cluster }.to \
        output("Merging into a large cluster. OCNs: [#{large_clusters.ocns.first}] and [1]\n")
        .to_stderr
      expect(Cluster.count).to eq(1)
    end

    it "is silent when merging 2 large clusters" do
      ht2 = build(:ht_item, ocns: [large_clusters.ocns.to_a.last])
      Clustering::ClusterHtItem.new(ht2).cluster
      expect(Cluster.count).to eq(2)
      glue = build(:ht_item, ocns: [large_clusters.ocns.to_a.last, large_clusters.ocns.first])

      expect { Clustering::ClusterHtItem.new(glue).cluster }.not_to output(/Merging/).to_stderr
      expect(Cluster.count).to eq(1)
    end
  end

  context "with missing large clusters files" do
    before(:each) do
      Settings.large_cluster_ocns = "file_that_does_not_exist"
    end

    it "does not raise error" do
      expect { described_class.new }.not_to raise_error
    end

    it "warns of missing file" do
      expect(Services.logger).to receive(:warn).with("No large clusters file found.")
      described_class.new
    end

    it "sets large_clusters to empty set" do
      expect(described_class.new.ocns).to be_empty
    end
  end
end
