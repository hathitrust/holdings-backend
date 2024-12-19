# frozen_string_literal: true

require "spec_helper"
require "cluster"
require "clustering/cluster_commitment"
require "clustering/cluster_ocn_resolution"
require "overlap/holding_commitment"
require "shared_print/finder"

RSpec.xdescribe Clustering::ClusterCommitment do
  let(:comm) { build(:commitment) }
  let(:batch) { [comm, build(:commitment, ocn: comm.ocn)] }
  let(:c) { create(:cluster, ocns: [comm.ocn]) }

  describe "#cluster" do
    before(:each) do
      Cluster.each(&:delete)
      c.save
    end

    context "when adding a new commitment" do
      it "adds a commitment to an existing cluster" do
        cluster = described_class.new(comm).cluster
        expect(cluster.commitments.first._parent.id).to eq(c.id)
        expect(cluster.commitments.count).to eq(1)
        expect(Cluster.count).to eq(1)
      end

      it "does NOT update cluster last modified date" do
        c.reload
        orig_last_modified = c.last_modified
        sleep(1)
        cluster = described_class.new(comm).cluster
        expect(cluster.last_modified).to eq(orig_last_modified)
      end

      it "creates a new cluster if no match is found" do
        expect(described_class.new(build(:commitment)).cluster.id).not_to eq(c.id)
        expect(Cluster.count).to eq(2)
      end

      it "can add a batch of commitments" do
        described_class.new(batch).cluster

        expect(Cluster.count).to eq(1)
        expect(Cluster.first.commitments.count).to eq(2)
      end
    end

    context "when re-adding an existing commitment" do
      it "doesn't add a commitment that already exists" do
        comm2 = comm.dup
        comm2.uuid = comm.uuid # dup does not give us the same uuid in the copy
        described_class.new(comm).cluster
        described_class.new(comm2).cluster
        expect(Cluster.count).to eq(1)
        expect(Cluster.first.commitments.count).to eq(1)
      end

      it "raises an error when two commitments with same uuid are in same batch" do
        comm2 = comm.dup
        comm2.uuid = comm.uuid # dup does not give us the same uuid in the copy
        expect { described_class.new([comm, comm2]).cluster }.to raise_exception(/same UUID/)
      end
    end
  end

  describe "#uuids_in_cluster" do
    it "gets a list of uuids in the cluster" do
      cc = described_class.new([comm, build(:commitment, ocn: comm.ocn)])
      cluster = cc.cluster
      expect(cc.uuids_in_cluster(cluster).count).to eq(2)
      expect(cc.uuids_in_cluster(cluster)).to include(comm.uuid)
    end
  end

  describe "merging/splitting a cluster w/ commitments" do
    before(:each) {
      Cluster.collection.find.delete_many
    }
    let(:ocn1) { 1 }
    let(:ocn2) { 2 }
    let(:reso) { build(:ocn_resolution, deprecated: ocn1, resolved: ocn2) }

    let(:finder) { SharedPrint::Finder.new(ocn: [ocn1, ocn2]) }
    it "Puts commitments together when their clusters merge." do
      # Start with 2 commitments on 2 clusters.
      [ocn1, ocn2].each do |ocn|
        cluster_tap_save(
          build(:ht_item, ocns: [ocn]),
          build(:holding, ocn: ocn, organization: "umich", mono_multi_serial: "spm", status: "CH", condition: ""),
          build(:commitment, ocn: ocn, organization: "umich")
        )
      end
      expect(finder.commitments.count).to eq 2
      expect(Cluster.count).to eq 2

      # Use reso as glue to merge the clusters.
      cluster_tap_save reso

      # Now find the 2 commitments on 1 merged cluster (with ocns [1, 2]).
      expect(finder.clusters.count).to eq 1
      expect(finder.commitments.count).to eq 2
      expect(finder.clusters.first.ocns.sort).to eq [ocn1, ocn2]
    end
    it "puts commitments separately if the cluster splits them" do
      # Here they start out in the same cluster (glued ht_item.ocns)
      expect(finder.clusters.count).to eq 0

      [ocn1, ocn2].each do |ocn|
        cluster_tap_save(
          build(:ht_item, ocns: [ocn]),
          build(:holding, ocn: ocn, organization: "umich", mono_multi_serial: "spm", status: "CH", condition: ""),
          build(:commitment, ocn: ocn, organization: "umich"),
          reso # this clusters them together from the start
        )
      end
      expect(finder.commitments.count).to eq 2
      expect(Cluster.count).to eq 1

      # Remove the reso glue to split the clusters.
      Clustering::ClusterOCNResolution.new(reso).delete

      # Now find the 2 commitments on 2 merged clusters (with ocns [1] & respectively [2]).
      clusters = finder.clusters.to_a
      expect(clusters.count).to eq 2
      expect(finder.commitments.count).to eq 2
      expect(clusters.first.ocns).to eq [ocn1]
      expect(clusters.last.ocns).to eq [ocn2]
    end
    it "can happen that splitting changes shared print eligibility" do
      # This cluster should be eligible for commitments.
      cluster_tap_save(
        build(:ht_item, ocns: [ocn1], bib_fmt: "BK", enum_chron: ""),
        build(:holding, ocn: ocn2, organization: "umich", mono_multi_serial: "spm", status: "CH", condition: ""),
        reso # this clusters them together from the start
      )

      # Confirm that it is.
      expect(Overlap::HoldingCommitment.new(ocn1).eligible_holdings.size).to eq 1
      # And since ocn 1 and 2 are in the same cluster, ocn2 is also eligible.
      expect(Overlap::HoldingCommitment.new(ocn2).eligible_holdings.size).to eq 1

      # Remove the reso glue to split the clusters. This should remove the ht_item
      # from the cluster, and break the commitment eligibility for ocn1.
      Clustering::ClusterOCNResolution.new(reso).delete

      # Glue gone, no longer eligible
      expect(Overlap::HoldingCommitment.new(ocn1).eligible_holdings.size).to eq 0
      expect(Overlap::HoldingCommitment.new(ocn2).eligible_holdings.size).to eq 0
    end
  end
end
