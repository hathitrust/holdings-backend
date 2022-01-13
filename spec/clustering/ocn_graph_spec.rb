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
      expect(g.vertices).to eq([:a, :b, :c])
    end

    it "adds edges for each pairwise combination in a tuple" do
      g.add_tuple([:a, :b, :c])
      expect(g.adjacent_vertices(:a)).to eq([:b, :c])
      expect(g.adjacent_vertices(:b)).to eq([:a, :c])
      expect(g.adjacent_vertices(:c)).to eq([:a, :b])
    end
  end

  describe "#subgraphs" do
    before(:each) do
      g.add_tuple(set_a)
      g.add_tuple(set_bc)
    end

    it "partitions a disconnected graph into multliple components" do
      expect(g.components.count).to eq(2)
      expect(g.components).to eq([[:a], [:c, :b]])
    end

    it "groups a connected graph into one component" do
      g.add_tuple(set_ab)
      expect(g.components.count).to eq(1)
      expect(g.components.first.sort).to eq([:a, :b, :c])
    end
  end
end
