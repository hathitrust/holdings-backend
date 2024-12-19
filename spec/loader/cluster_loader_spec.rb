# frozen_string_literal: true

require "spec_helper"
require "loader/cluster_loader"
require "clusterable/commitment"
require "clusterable/holding"
require "clusterable/ht_item"

RSpec.xdescribe Loader::ClusterLoader do
  let(:loader) { described_class.new }
  let(:file) { "spec/fixtures/cluster_2503661.json" }
  let(:ocn) { 2503661 }

  before(:each) do
    Cluster.collection.find.delete_many
  end

  def count_clusters
    Cluster.for_ocns([ocn]).count
  end

  describe "#load" do
    it "loads a file" do
      expect(count_clusters).to eq 0
      loader.load(file)
      expect(count_clusters).to eq 1
    end

    it "makes clusterables" do
      loader.load(file)
      cluster = Cluster.find_by(ocns: ocn)
      expect(cluster.commitments.first).to be_a Clusterable::Commitment
      expect(cluster.holdings.first).to be_a Clusterable::Holding
      expect(cluster.ht_items.first).to be_a Clusterable::HtItem
    end
  end

  describe "#load_array" do
    it "loads a array of hashes" do
      data = JSON.parse(File.read(file))
      expect(count_clusters).to eq 0
      loader.load_array(data)
      expect(count_clusters).to eq 1
    end
  end

  describe "attr_readers" do
    it "are readable and increment as expected" do
      expect(loader.attempted_files).to eq 0
      expect(loader.attempted_docs).to eq 0
      expect(loader.success_docs).to eq 0
      expect(loader.fail_docs).to eq 0
      loader.load(file)
      expect(loader.attempted_files).to eq 1
      expect(loader.attempted_docs).to eq 1
      expect(loader.success_docs).to eq 1
      expect(loader.fail_docs).to eq 0
    end
  end

  describe "#stats" do
    it "reports stats (essentially prettyprint attr_readers)" do
      expect(loader.stats).to eq "Files attempted:0, total docs:0, success:0, fail:0"
      loader.load(file)
      expect(loader.stats).to eq "Files attempted:1, total docs:1, success:1, fail:0"
      loader.load(file)
      expect(loader.stats).to eq "Files attempted:2, total docs:2, success:1, fail:1"
    end
  end
end
