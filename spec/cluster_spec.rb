# frozen_string_literal: true

require "cluster"

RSpec.describe Cluster do
  let(:id1) { double("id1") }
  let(:id2) { double("id2") }
  let(:id3) { double("id3") }
  let(:members) { [id1, id2, id3] }

  context "with a cluster with only one member" do
    let(:cluster) { described_class.new(id1) }

    it "can be created" do
      expect(cluster).not_to be(nil)
    end

    it "includes that member" do
      expect(cluster.include?(id1)).to be(true)
    end
  end

  context "with a cluster with multiple members" do
    let(:cluster) { described_class.new(id1, id2) }

    it "can be created" do
      expect(cluster).not_to be(nil)
    end

    it "can tell whether a member is included in the cluster" do
      expect(cluster.include?(id1)).to be(true)
    end
  end

  describe "#merge" do
    let(:cluster1) { described_class.new(id1) }
    let(:cluster2) { described_class.new(id2) }

    it "includes both members after merge" do
      expect(cluster1.merge(cluster2).members).to\
        contain_exactly(id1, id2)
    end
  end

  describe "#from_hash" do
    let(:hash) { { members: [id1, id2, id3] } }
    let(:cluster_from_hash) { described_class.from_hash(hash) }

    it "maps members" do
      expect(cluster_from_hash.members).to contain_exactly(id1, id2, id3)
    end
  end

  describe "#add" do
    it "returns a cluster with the new id as a member" do
      expect(described_class.new(id1).add(id2)).to include(id2)
    end
  end

  describe "#to_hash" do
    let(:cluster) { described_class.new(*members) }

    it "converts to hash" do
      expect(cluster.to_hash).to eq(members: members)
    end
  end
end
