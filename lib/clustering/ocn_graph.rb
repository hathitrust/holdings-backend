# frozen_string_literal: true

require "cluster"

module Clustering

  # Constructs a graph from OCN tuples
  class OCNGraph

    attr_accessor :edges, :nodes

    def initialize(cluster = nil)
      @cluster = cluster
      @nodes = Set.new
      # root_ocn : [all matching ocns]
      @edges = Hash.new {|g, root| g[root] = Set.new }
      compile_graph_from_cluster unless @cluster.nil?
    end

    # Add the tuple of OCNs to the list of nodes and edges
    #
    # @param [Enumerable] tuple A set of one or more OCNs from a clusterable
    def add_tuple(tuple)
      nodes.merge(tuple)
      tuple.map {|node| edges[node] << node }
      tuple.sort.to_a.combination(2).each do |parent, child|
        edges[parent] << child
        edges[child] << parent
      end
    end

    # root, children = edges.sort.first

    # Partition the :nodes into one or more subgraphs
    #
    # TODO: better name. really just subsets of OCNS
    def subgraphs
      @subgraphs = []
      roots_not_seen = edges.keys.sort.to_set
      while roots_not_seen.any?
        root = roots_not_seen.first
        nodes_visited = dfs_traverse(root, Set.new)
        @subgraphs << nodes_visited
        roots_not_seen -= nodes_visited
      end
      @subgraphs
    end

    # Recursively traverse the graph starting at the root.
    # Compile the list of OCNs visited from a particular root.
    #
    # @param root The node to start the traversal.
    # @param [Set] nodes_visited The set of OCNs we have already traversed.
    def dfs_traverse(root, nodes_visited)
      nodes_visited << root
      edges[root].each do |child|
        next if nodes_visited.include? child

        nodes_visited << child
        dfs_traverse(child, nodes_visited)
      end
      nodes_visited
    end

    # Compile the graph from the given cluster
    def compile_graph_from_cluster
      @cluster.ht_items.pluck(:ocns).map {|tuple| add_tuple(tuple) }
      @cluster.ocn_resolutions.pluck(:ocns).map {|tuple| add_tuple(tuple) }
      @cluster.holdings.pluck(:ocn).map {|o| add_tuple([o]) }
      @cluster.commitments.pluck(:ocn).map {|o| add_tuple([o]) }
    end
  end
end
