# frozen_string_literal: true

require "cluster"

RSpec.describe Cluster do
  let(:member1) { double("member1") }
  let(:member2) { double("member2") }
  let(:members) { [member1, member2] }
  let(:id) { double("id") }

  context "with a cluster with only a cluster id" do
    let(:cluster) { described_class.new(id) }

    it "can be created" do
      expect(cluster).not_to be(nil)
    end

    it "includes its own id" do
      expect(cluster.include?(id)).to be(true)
    end
  end

  it "can be created with only a cluster id" do
    expect(described_class.new(id)).not_to be(nil)
  end

  context "with a cluster with two members" do
    let(:cluster) { described_class.new(id, members) }

    it "can be created" do
      expect(cluster).not_to be(nil)
    end

    it "can retrieve its resolved id" do
      expect(cluster.id).to eq(id)
    end

    it "can tell whether a member is included in the cluster" do
      expect(cluster.include?(members[0])).to be(true)
    end

    it "includes its own id" do
      expect(cluster.include?(id)).to be(true)
    end
  end

  describe "#merge" do
    let(:cluster1) { described_class.new(member1) }
    let(:cluster2) { described_class.new(member2) }

    it "includes both members after merge" do
      expect(cluster1.merge(cluster2).members).to\
        contain_exactly(member1, member2)
    end
  end
end
