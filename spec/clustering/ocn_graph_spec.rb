# frozen_string_literal: true

require "spec_helper"
require "clustering/ocn_graph"

RSpec.describe Clustering::OCNGraph do
  let(:set_a) { Set.new([:a]) }
  let(:set_ab) { Set.new([:a, :b]) }
  let(:set_bc) { Set.new([:b, :c]) }
  let(:g) { described_class.new }

  describe "#add_tuple"  do
    it "adds all ocns in a tuple to @nodes" do
      g.add_tuple([:a, :b, :c])
      expect(g.nodes).to eq(Set.new([:a, :b, :c]))
    end

    it "adds edges for each pairwise combination in a tuple" do
      g.add_tuple([:a, :b, :c])
      expect(g.edges[:a]).to eq(Set.new([:a, :b, :c]))
      expect(g.edges[:b]).to eq(Set.new([:b, :a, :c]))
      expect(g.edges[:c]).to eq(Set.new([:c, :a, :b]))
    end

    it "adds an edge for a node in a tuple of 1" do
      g.add_tuple([:a])
      expect(g.edges[:a]).to eq(Set.new([:a]))
    end
  end

  describe "#subgraphs" do
    before(:each) do
      g.add_tuple(set_a)
      g.add_tuple(set_bc)
    end

    it "partitions a disconnected graph into multliple subgraphs" do
      expect(g.subgraphs.count).to eq(2)
      expect(g.subgraphs).to eq([Set.new([:a]), Set.new([:b, :c])])
    end

    it "groups a connected graph into one subgraph" do
      g.add_tuple(set_ab)
      expect(g.subgraphs.count).to eq(1)
      expect(g.subgraphs.first).to eq(Set.new([:a, :b, :c]))
    end
  end
end
