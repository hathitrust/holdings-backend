# frozen_string_literal: true

require "cluster"
require "rgl/adjacency"
require "rgl/connected_components"

module Clustering

  # Constructs a graph from OCN tuples
  class OCNGraph < RGL::AdjacencyGraph

    def initialize(cluster = nil)
      super(Set)
      @cluster = cluster
      compile_graph_from_cluster unless @cluster.nil?
    end

    # Add the tuple of OCNs to the list of edges
    #
    # @param [Enumerable] tuple A set of one or more OCNs from a clusterable
    def add_tuple(tuple)
      add_vertices(*tuple)
      tuple.sort.to_a.combination(2).each {|parent, child| add_edge(parent, child) }
    end

    # Partition the vertices into one or more components
    def components
      @components ||= enum_for(:each_connected_component).to_a
    end

    # Compile the graph from the given cluster
    def compile_graph_from_cluster
      @cluster.component_ocns.map {|tuple| add_tuple([tuple].flatten) }
    end
  end
end
