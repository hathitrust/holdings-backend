# frozen_string_literal: true

require "spec_helper"
require "clusterable/commitment"
require "cluster"
require "clustering/cluster_commitment"

RSpec.describe Clusterable::Commitment do
  let(:c) { create(:cluster) }
  let(:comm) { build(:commitment) }

  it "does not have a parent" do
    expect(build(:commitment)._parent).to be_nil
  end

  it "has a parent cluster" do
    c.commitments << build(:commitment)
    expect(c.commitments.first._parent).to be(c)
  end

  it "validates local_shelving_type" do
    expect(comm.valid?).to be true
    comm.local_shelving_type = "invalid"
    expect(comm.valid?).to be false
    comm.local_shelving_type = "cloa"
    expect(comm.valid?).to be true
  end

  describe "deprecated?" do
    it "is deprecated if it has a deprecation status" do
      expect(comm.deprecated?).to be false
      expect(build(:commitment, :deprecated).deprecated?).to be true
    end

    it "validates deprecation" do
      expect(comm.valid?).to be true
      comm.deprecation_status = "C"
      expect(comm.valid?).to be false
    end
  end

  describe "batch_with?" do
    let(:comm1) { build(:commitment, ocn: 123) }
    let(:comm2) { build(:commitment, ocn: 123) }
    let(:comm3) { build(:commitment, ocn: 456) }

    it "batches with a commitment with the same ocn" do
      expect(comm1.batch_with?(comm2)).to be true
    end

    it "doesn't batch with a commitment with a different ocn" do
      expect(comm1.batch_with?(comm3)).to be false
    end
  end

  describe "matching_holdings" do
    before(:each) do
      Cluster.each(&:delete)
    end

    let(:h) do
      build(:holding, ocn: comm.ocn, organization: comm.organization, local_id: comm.local_id)
    end

    it "finds holdings matching this commitment" do
      Clustering::ClusterHolding.new(h).cluster
      Clustering::ClusterCommitment.new(comm).cluster
      expect(Cluster.first.commitments.first.matching_holdings).to eq([h])
    end
  end
end
