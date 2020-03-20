# frozen_string_literal: true

require "holding"
require "cluster"

RSpec.describe Holding do
  let(:ocn_rand) { rand(1_000_000).to_i }
  let(:holding_hash) do
    { ocns:              [ocn_rand],
      organization:      "miu",
      local_id:          "abc",
      mono_multi_serial: "mono" }
  end
  let(:h) { described_class.new(holding_hash) }

  it "can be created" do
    expect(described_class.new(holding_hash)).to be_a(described_class)
  end

  it "has at least 1 ocn" do
    expect(h.ocns.first).to be_a(Integer)
  end

  it "has an organization" do
    expect(h.organization).to be_a(String)
  end

  it "has a local id" do
    expect(h.local_id).to be_a(String)
  end

  it "has a mono_multi_serial" do
    expect(h.mono_multi_serial).to be_a(String)
  end

  it "requires mono_multi_serial to be one of the values" do
    h.mono_multi_serial = "recording"
    expect(h.valid?).to be false
    h.mono_multi_serial = "multi"
    expect(h.valid?).to be true
  end

  describe "#ocns_updated" do
    it "can track the ocns seen by the class" do
      described_class.ocns_updated << 5
      expect(described_class.new.ocns_updated).to include(5)
    end
  end

  describe "#self.add" do
    before(:each) do
      Cluster.each(&:delete)
    end

    let(:c) { create(:cluster, ocns: [5, 7, holding_hash[:ocns]].flatten) }
    let(:c2) { create(:cluster, ocns: [8, 999]) }
    let(:hold_hash_multi_ocn) do
      { ocns:              [7, 8],
        organization:      "miu",
        local_id:          "abc",
        mono_multi_serial: "mono" }
    end

    after(:each) do
      Cluster.each(&:delete)
    end

    it "adds a holding with one OCN to the appropriate cluster" do
      cluster = described_class.add(holding_hash)
      expect(cluster.holdings.count).to eq(1)
      expect(cluster.holdings.first.local_id).to eq("abc")
    end

    it "creates a cluster if no cluster is found" do
      expect(Cluster.count).to eq(0)
      described_class.add(holding_hash)
      expect(Cluster.count).to eq(1)
      expect(Cluster.first.holdings.first.local_id).to \
        eq(holding_hash[:local_id])
    end

    it "adds a holding with multi OCNs to the appropriate cluster" do
      cluster = described_class.add(hold_hash_multi_ocn)
      expect(cluster.holdings.count).to eq(1)
      expect(cluster.holdings.first.local_id).to eq("abc")
    end

    it "creates a cluster from a holding with multi OCNS using first" do
      cluster = described_class.add(hold_hash_multi_ocn)
      expect(cluster.holdings.count).to eq(1)
      expect(cluster.ocns.count).to eq(1)
      expect(cluster.holdings.first.local_id).to eq("abc")
    end

    it "only adds to first cluster it finds if it has multiple OCNS" do
      c
      c2
      described_class.add(hold_hash_multi_ocn)
      expect(Cluster.where(_id: c._id).first.holdings.count).to eq(1)
      expect(Cluster.where(_id: c2._id).first.holdings.count).to eq(0)
    end
  end

  describe "#self.update" do
    let(:c) { create(:cluster) }
    let(:h) { holding_hash }

    before(:each) do
      Cluster.each(&:delete)
      c
      h[:ocns] = [c.ocns.first]
      c.holdings.create(h)
    end

    after(:each) do
      described_class.ocns_updated = Set.new
      Cluster.each(&:delete)
    end

    it "destroys previous holdings if it HAS NOT seen the ocn" do
      expect(described_class.ocns_updated).not_to include(h[:ocns].first)
      cluster = described_class.update(h.clone)
      expect(cluster.holdings.count).to eq(1)
      expect(described_class.ocns_updated).to include(h[:ocns].first)
    end

    it "adds to the cluster if it HAS seen the ocn" do
      cluster = described_class.update(h.clone)
      expect(cluster.holdings.count).to eq(1)
      expect(described_class.ocns_updated).to include(h[:ocns].first)
      cluster = described_class.update(h.clone)
      expect(cluster.holdings.count).to eq(2)
    end
  end

  describe "#self.delete_holdings" do
    let(:c) { create(:cluster) }
    let(:h) { holding_hash }

    before(:each) do
      c
      c.holdings.create(h)
    end

    after(:each) do
      described_class.ocns_updated = Set.new
      Cluster.each(&:delete)
    end

    it "destroys all holdings for a particular member/ocn pair" do
      expect(c.holdings.count).to eq(1)
      described_class.delete(h[:organization], c.ocns)
      expect(Cluster.where(_id: c._id).first.holdings.count).to eq(0)
    end

    it "returns the OCNs in the clusters affected" do
      expect(described_class.delete(h[:organization], c.ocns)).to eq(c.ocns)
    end
  end
end
