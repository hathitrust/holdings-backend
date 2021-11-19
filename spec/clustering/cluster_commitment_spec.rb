# frozen_string_literal: true

require "spec_helper"
require "clustering/cluster_commitment"

RSpec.describe Clustering::ClusterCommitment do
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
        described_class.new(comm).cluster
        described_class.new(comm2).cluster
        expect(Cluster.count).to eq(1)
        expect(Cluster.first.commitments.count).to eq(1)
      end

      it "raises an error when two commitments with same uuid are in same batch" do
        comm2 = comm.dup
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
end
