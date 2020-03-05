# frozen_string_literal: true

require "holding"
require "cluster"
require "pp"
RSpec.describe Holding do
  let(:ocn_rand) { rand(1_000_000).to_i }
  let(:holding_hash) do
    { ocn:               ocn_rand,
      organization:      "miu",
      local_id:          "abc",
      mono_multi_serial: "mono" }
  end
  let(:h) { described_class.new(holding_hash) }

  it "can be created" do
    expect(described_class.new(holding_hash)).to be_a(described_class)
  end

  it "has an ocn" do
    expect(h.ocn).to be_a(Integer)
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

    let(:c) { Cluster.new(ocns: [5, 7, holding_hash[:ocn]]) }
    let(:hold_hash_multi_ocn) do
      { ocn:               [7, 8],
        organization:      "miu",
        local_id:          "abc",
        mono_multi_serial: "mono" }
    end

    after(:each) do
      Cluster.each(&:delete)
    end

    it "adds a holding with one OCN to the appropriate cluster" do
      c.save
      cluster = described_class.add(holding_hash)
      expect(cluster.holdings.count).to eq(1)
      expect(cluster.holdings.first.local_id).to eq("abc")
    end

    it "creates a cluster if no cluster is found" do
      expect(Cluster.count).to eq(0)
      described_class.add(holding_hash)
      expect(Cluster.count).to eq(1)
      expect(Cluster.first.holdings.first.local_id).to eq("abc")
    end

    it "adds a holding with multi OCNs to the appropriate cluster" do
      c.save
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
  end

  describe "#self.update" do
    let(:c) { Cluster.new(ocns: [ocn_rand]) }
    let(:h) { holding_hash }

    before(:each) do
      Cluster.each(&:delete)
      c.save
      h[:ocn] = c.ocns.first
      c.holdings.create(h)
    end

    after(:each) do
      described_class.ocns_updated = Set.new
      Cluster.each(&:delete)
    end

    it "destroys previous holdings if it HAS NOT seen the ocn" do
      expect(described_class.ocns_updated).not_to include(h[:ocn])
      c = described_class.update(h.clone)
      expect(c.holdings.count).to eq(1)
      expect(described_class.ocns_updated).to include(h[:ocn])
    end

    it "adds to the cluster if it HAS seen the ocn" do
      c = described_class.update(h.clone)
      expect(c.holdings.count).to eq(1)
      expect(described_class.ocns_updated).to include(h[:ocn])
      c = described_class.update(h.clone)
      expect(c.holdings.count).to eq(2)
    end
  end
end
