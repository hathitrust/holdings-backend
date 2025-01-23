# frozen_string_literal: true

require "spec_helper"
require "clustering/cluster_ocn_resolution"

RSpec.describe Clustering::ClusterOCNResolution do
  let(:resolution) { build(:ocn_resolution) }
  let(:resolution2) { build(:ocn_resolution, resolved: resolution.resolved) }

  let(:c) { build(:cluster, ocns: resolution.ocns) }

  describe "#cluster" do
    include_context "with cluster ocns table"
    before(:each) { Services.holdings_db[:oclc_concordance].truncate }

    it "can add a batch" do
      cluster = described_class.new(resolution, resolution2).cluster

      expect(cluster.ocn_resolutions.to_a.size).to eq(2)
      expect(cluster.ocns).to contain_exactly(resolution.deprecated,
        resolution.resolved,
        resolution2.deprecated)
      expect(Cluster.count).to eq(1)
    end

    it "ignores duplicate resolution rules" do
      described_class.new(resolution, resolution2).cluster
      cluster = described_class.new(resolution.dup).cluster

      expect(cluster.ocn_resolutions.to_a.size).to eq(2)
      expect(cluster.ocns).to contain_exactly(resolution.deprecated,
        resolution.resolved,
        resolution2.deprecated)
      expect(Cluster.count).to eq(1)
    end

    it "adds an OCN Resolution to an existing cluster" do
      # Persists a cluster with the resolution rule's OCNs, but without the
      # resolution rule
      c.save

      cluster = described_class.new(resolution).cluster

      expect(cluster.ocn_resolutions.first.cluster.id).to eq(c.id)
      expect(cluster.ocn_resolutions.to_a.size).to eq(1)
      expect(Cluster.count).to eq(1)
    end

    xit "updates modified date when adding OCN Resolution" do
      c.save
      orig_last_modified = c.last_modified
      cluster = described_class.new(resolution).cluster
      expect(cluster.last_modified).to be > orig_last_modified
    end

    it "creates a new cluster if no match is found" do
      c.save
      new_cluster = described_class.new(build(:ocn_resolution)).cluster
      expect(new_cluster.id).not_to eq(c.id)
      expect(Cluster.each.to_a.size).to eq(2)
    end

    it "adds a resolution with matching OCN to an existing cluster" do
      described_class.new(resolution).cluster
      described_class.new(resolution2).cluster

      expect(Cluster.count).to eq(1)
      expect(Cluster.first.ocn_resolutions.to_a.size).to eq(2)
      expect(Cluster.first.ocns).to contain_exactly(resolution.deprecated,
        resolution2.deprecated,
        resolution.resolved)
    end

    xit "merges two or more clusters" do
      # first cluster with resolution's ocns
      create(:cluster, ocns: [resolution.deprecated])
      # a second cluster with different ocns
      create(:cluster, ocns: [resolution.resolved])
      described_class.new(resolution).cluster

      expect(Cluster.each.to_a.size).to eq(1)
      cluster = Cluster.first
      expect(cluster.ocn_resolutions.to_a.size).to eq(1)
      expect(cluster.ocns.size).to eq(2)
    end

    it "cluster has its resolutions ocns" do
      cluster = described_class.new(resolution).cluster
      expect(cluster.ocns.to_a).to eq(resolution.ocns.to_a)
    end
  end

  xdescribe "#delete" do
    before(:each) do
      Cluster.each(&:delete)
      c.save
      described_class.new(resolution).cluster.save
      described_class.new(resolution2).cluster.save
    end

    it "results in a single cluster without the resolution rule" do
      described_class.new(resolution2).delete
      clusters = Cluster.where(ocns: resolution.resolved)
      expect(clusters.to_a.size).to eq(1)
      expect(clusters.first.ocn_resolutions.to_a.size).to eq(1)
    end

    it "has no clusters with the deprecated OCN from the deleted rule" do
      described_class.new(resolution2).delete
      clusters = Cluster.where(ocns: resolution2.deprecated)
      expect(clusters.to_a.size).to eq(0)
    end

    it "removes the old deprecated OCN from the cluster" do
      described_class.new(resolution2).delete

      cluster = Cluster.where(ocns: resolution.resolved).first
      expect(cluster.ocns).to contain_exactly(*resolution.ocns)
    end

    context "with HtItems matching OCNs from both rules" do
      before(:each) do
        [resolution.deprecated,
          resolution.resolved,
          resolution2.deprecated].each do |ocn|
          Clustering::ClusterHtItem.new(build(:ht_item, ocns: [ocn])).cluster.save
        end
      end

      it "creates a new cluster with the deprecated OCN from the deleted rule" do
        described_class.new(resolution2).delete
        clusters = Cluster.where(ocns: resolution2.deprecated)
        expect(clusters.to_a.size).to eq(1)
        expect(clusters.first.ocns).to contain_exactly(resolution2.deprecated)
        expect(clusters.first.ocn_resolutions.to_a.size).to eq(0)
      end

      it "cluster with remaining resolution rule has correct HtItems" do
        described_class.new(resolution2).delete

        cluster_htitem_ocns = Cluster.where(ocns: resolution.resolved)
          .first.ht_items.map(&:ocns)

        expect(cluster_htitem_ocns).to contain_exactly(
          [resolution.deprecated], [resolution.resolved]
        )
      end

      it "cluster with deprecated OCN from deleted rule has correct HtItem" do
        described_class.new(resolution2).delete

        cluster_htitem_ocns = Cluster.where(ocns: resolution2.deprecated)
          .first.ht_items.map(&:ocns)

        expect(cluster_htitem_ocns).to contain_exactly([resolution2.deprecated])
      end
    end
  end
end
