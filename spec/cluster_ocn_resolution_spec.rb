# frozen_string_literal: true

require "cluster_ocn_resolution"
RSpec.describe ClusterOCNResolution do
  let(:resolution) { build(:ocn_resolution) }
  let(:c) { create(:cluster, ocns: resolution.ocns) }

  describe "#cluster" do
    before(:each) do
      Cluster.each(&:delete)
    end

    it "adds an OCN Resolution to an existing cluster" do
      c.save
      cluster = described_class.new(resolution).cluster
      expect(cluster.ocn_resolutions.first._parent.id).to eq(c.id)
      expect(cluster.ocn_resolutions.to_a.size).to eq(1)
      expect(Cluster.each.to_a.size).to eq(1)
    end

    it "creates a new cluster if no match is found" do
      c.save
      new_cluster = described_class.new(build(:ocn_resolution)).cluster
      expect(new_cluster.id).not_to eq(c.id)
      expect(Cluster.each.to_a.size).to eq(2)
    end

    it "merges two or more clusters" do
      # first cluster with resolution's ocns
      create(:cluster, ocns: [resolution.deprecated])
      # a second cluster with different ocns
      create(:cluster, ocns: [resolution.resolved])
      cluster = described_class.new(resolution).cluster
      expect(Cluster.each.to_a.size).to eq(1)
      expect(cluster.ocn_resolutions.to_a.size).to eq(1)
      expect(cluster.ocns.size).to eq(2)
    end

    it "cluster has it's embed's ocns" do
      cluster = described_class.new(resolution).cluster
      expect(cluster.ocns).to eq(resolution.ocns)
    end
  end

  describe "#move" do
    let(:c2) { create(:cluster) }

    before(:each) do
      Cluster.each(&:delete)
      c.save
    end

    it "moves an OCN resolution from one cluster to another" do
      cluster = described_class.new(resolution).cluster
      expect(cluster.ocn_resolutions.to_a.size).to eq(1)
      described_class.new(resolution).move(c2)
      expect(cluster.ocn_resolutions.to_a.size).to eq(0)
      expect(c2.ocns).to eq(resolution.ocns)
    end
  end
end
