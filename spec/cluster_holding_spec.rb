# frozen_string_literal: true

require "cluster_holding"
require "pp"
RSpec.describe ClusterHolding do
  let(:h) { build(:holding) }
  let(:c) { create(:cluster, ocns: [h.ocn]) }

  describe "#cluster" do
    before(:each) do
      Cluster.each(&:delete)
      # @h = build(:holding)
      # @c = create(:cluster, ocns: [@h.ocn])
      c.save
    end

    it "adds a holding to an existing cluster" do
      cluster = described_class.new(h).cluster
      expect(cluster.holdings.first._parent.id).to eq(c.id)
      expect(cluster.holdings.to_a.size).to eq(1)
      expect(Cluster.each.to_a.size).to eq(1)
    end

    it "creates a new cluster if no match is found" do
      expect(described_class.new(build(:holding)).cluster.id).not_to eq(c.id)
      expect(Cluster.each.to_a.size).to eq(2)
    end
  end

  describe "#move" do
    let(:c2) { create(:cluster) }

    before(:each) do
      Cluster.each(&:delete)
      c.save
    end

    it "moves a holding from one cluster to another" do
      cluster = described_class.new(h).cluster
      expect(cluster.holdings.to_a.size).to eq(1)
      described_class.new(h).move(c2)
      expect(cluster.holdings.to_a.size).to eq(0)
      expect(c2.holdings.to_a.size).to eq(1)
    end
  end
end
