# frozen_string_literal: true

require "spec_helper"
require "clusterable/commitment"
require "cluster"
require "clustering/cluster_commitment"

RSpec.xdescribe Clusterable::Commitment do
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
    expect(comm).to be_valid
    comm.local_shelving_type = "invalid"
    expect(comm).not_to be_valid
    comm.local_shelving_type = "cloa"
    expect(comm).to be_valid
  end

  it "has a uuid" do
    expect(comm.uuid).not_to be_nil
    expect(comm.uuid).not_to be_empty
  end

  it "gets a default committed_date if none given" do
    new_empty = Clusterable::Commitment.new({})
    expect(new_empty.committed_date).to eq DateTime.new(Time.now.year, 1, 1)
  end

  describe "deprecated?" do
    it "is deprecated if it has a deprecation status" do
      expect(comm).not_to be_deprecated
      expect(build(:commitment, :deprecated)).to be_deprecated
    end

    it "validates deprecation" do
      expect(comm).to be_valid
      comm.deprecation_status = "C"
      expect(comm).not_to be_valid
    end
  end

  describe "deprecate" do
    it "deprecate sets deprecated? == true" do
      c.commitments << comm
      depped = c.commitments.first
      expect(depped).not_to be_deprecated
      depped.deprecate(status: "C")
      expect(depped).to be_deprecated
    end

    it "adds status, date and replacement id" do
      c.commitments << comm
      replacement = build(:commitment, ocn: comm.ocn)
      depped = c.commitments.first
      d = DateTime.parse("2020-01-01")
      expect(depped).not_to be_deprecated
      depped.deprecate(status: "C", replacement: replacement, date: d)
      expect(depped).to be_deprecated
      expect(depped.deprecation_status).to eq("C")
      expect(depped.deprecation_date).to eq(d)
      expect(depped.deprecation_replaced_by).to eq(replacement._id.to_s)
    end

    it "replacement is optional" do
      c.commitments << comm
      depped = c.commitments.first
      d = DateTime.parse("2020-02-02")
      depped.deprecate(status: "D", date: d)
      expect(depped.deprecation_status).to eq("D")
      expect(depped.deprecation_date).to eq(d)
      expect(depped.deprecation_replaced_by).to eq nil
    end

    it "date is optional" do
      c.commitments << comm
      depped = c.commitments.first
      depped.deprecate(status: "E")
      expect(depped.deprecation_status).to eq("E")
      expect(depped.deprecation_date).to eq(Date.today)
      expect(depped.deprecation_replaced_by).to eq nil
    end
  end

  describe "batch_with?" do
    let(:comm1) { build(:commitment, ocn: 123) }
    let(:comm2) { build(:commitment, ocn: 123) }
    let(:comm3) { build(:commitment, ocn: 456) }

    it "batches with a commitment with the same ocn" do
      expect(comm1).to be_batch_with(comm2)
    end

    it "doesn't batch with a commitment with a different ocn" do
      expect(comm1).not_to be_batch_with(comm3)
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

  describe "policies" do
    it "accepts empty policy" do
      expect(build(:commitment, policies: [])).to be_valid
    end

    ["blo", "digitizeondemand", "non-circ", "non-repro"].each do |policy|
      it "accepts #{policy}" do
        expect(build(:commitment, policies: [policy])).to be_valid
      end
    end

    it "accepts multiple policies" do
      expect(build(:commitment, policies: ["blo", "digitizeondemand"])).to be_valid
    end

    it "rejects other policies" do
      expect(build(:commitment, policies: ["unknown"])).not_to be_valid
    end
  end
end
