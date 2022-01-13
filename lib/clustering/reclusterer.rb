# frozen_string_literal: true

require "cluster"
require "clustering/cluster_ocn_resolution"
require "clustering/cluster_holding"
require "clustering/cluster_ht_item"
require "clustering/cluster_commitment"
require "clustering/ocn_graph"

module Clustering
  # Determines if a cluster needs reclustering.
  # Deletes a cluster, then re-creates clusters from the data in that cluster.
  class Reclusterer

    def initialize(cluster, removed_ocn_tuple = nil)
      @cluster = cluster
      @removed_ocn_tuple = removed_ocn_tuple || []
    end

    def recluster
      return @cluster.delete if @cluster.empty?

      @cluster.update_ocns if ocns_changed?
      return unless needs_recluster?

      if @cluster.large?
        raise LargeClusterError,
              "Reclustering large cluster will lead to incomplete holdings. " \
              "OCNs: #{@cluster.ocns.join(", ")}"
      end

      Retryable.with_transaction do
        Services.logger.debug "Deleting and reclustering cluster #{@cluster.inspect}"
        @cluster.delete

        recluster_components
      end
    end

    # The removed_ocn_tuple include an OCN no longer found in the remaining components
    def ocns_changed?
      return false if @removed_ocn_tuple.none?

      (@removed_ocn_tuple - @cluster.component_ocns.flatten.uniq).any?
    end

    # Determines if all component OCNs are connected.
    # Uses simple tests before attempting more involved graph traversal.
    def needs_recluster?
      return false if @cluster.ocns.one? ||
        resolution_includes_cluster_ocns? ||
        removed_ocn_tuple_equals_current_resolution? ||
        removed_ocn_tuple_is_subset_of_ht_item?

      graph = OCNGraph.new(@cluster)
      graph.components.count > 1
    end

    private

    # By definition, if a cluster has an OCLC resolution and only 2 OCNs then
    # the cluster is coherent.
    def resolution_includes_cluster_ocns?
      @cluster.ocns.count == 2 && @cluster.ocn_resolutions.one?
    end

    def removed_ocn_tuple_equals_current_resolution?
      @cluster.ocn_resolutions.pluck(:ocns).any? {|ocns| @removed_ocn_tuple.sort == ocns.sort }
    end

    def removed_ocn_tuple_is_subset_of_ht_item?
      return false if @removed_ocn_tuple.none?

      @cluster.ht_items.pluck(:ocns).any? {|ocns| @removed_ocn_tuple.to_set.subset? ocns.to_set }
    end

    def cluster_components
      @cluster.holdings + @cluster.ht_items + @cluster.ocn_resolutions + @cluster.commitments
    end

    def recluster_components
      @cluster.ocn_resolutions
        .each {|r| ClusterOCNResolution.new(r.dup).cluster.save }
      recluster_ht_items
      recluster_holdings
      recluster_commitments
    end

    def recluster_batch(clusterables, sort_field, clusterer)
      clusterables.sort_by(&sort_field)
        .chunk_while {|item1, item2| item1.batch_with?(item2) }
        .each {|batch| clusterer.new(*batch.map(&:dup)).cluster.save }
    end

    def recluster_ht_items
      recluster_batch(@cluster.ht_items, :ocns, ClusterHtItem)
    end

    def recluster_holdings
      recluster_batch(@cluster.holdings, :ocn, ClusterHolding)
    end

    def recluster_commitments
      recluster_batch(@cluster.commitments, :ocn, ClusterCommitment)
    end

  end
end
