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
    # removed_ocn_tuple is the set of OCNs in a deleted HTItem or OCNResolution
    # N.B. updated HTItems may have their OCNs changed, but no removed_ocn_tuple is provided
    def initialize(cluster, removed_ocn_tuple = nil)
      @cluster = cluster
      @removed_ocn_tuple = removed_ocn_tuple || []
    end

    def recluster
      return @cluster.delete if @cluster.empty?

      # Ensure @cluster.ocns reflects the OCNS of its components
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

    # The removed_ocn_tuple includes an OCN no longer found in the remaining components
    def ocns_changed?
      return false if @removed_ocn_tuple.none?

      (@removed_ocn_tuple - @cluster.clusterable_ocn_tuples.flatten.uniq).any?
    end

    # Determines if all component OCNs are connected.
    # Uses simple tests before attempting more involved graph traversal.
    def needs_recluster?
      return false if @cluster.ocns.one? ||
        resolution_includes_cluster_ocns? ||
        removed_ocn_tuple_equals_current_resolution? ||
        removed_ocn_tuple_is_subset_of_ht_item?

      # The OCN graph will have multiple subgraphs if the cluster's OCN tuples are not connected.
      graph.subgraphs.count > 1
    end

    private

    def graph
      @graph ||= OCNGraph.new(@cluster)
    end

    # By definition, if a cluster has an OCLC resolution and only 2 OCNs then
    # the cluster is coherent.
    def resolution_includes_cluster_ocns?
      @cluster.ocns.count == 2 && @cluster.ocn_resolutions.one?
    end

    # An OCN Resolution in the cluster duplicates the removed_ocn_tuple.
    def removed_ocn_tuple_equals_current_resolution?
      return false if @removed_ocn_tuple.none?

      @cluster.ocn_resolutions.pluck(:ocns).any? { |ocns| @removed_ocn_tuple.sort == ocns.sort }
    end

    # The cluster has an HTItem with OCNs with sufficient glue to "cover" for the
    # removed_ocn_tuple
    def removed_ocn_tuple_is_subset_of_ht_item?
      return false if @removed_ocn_tuple.none?

      @cluster.ht_items.pluck(:ocns).any? { |ocns| @removed_ocn_tuple.to_set.subset? ocns.to_set }
    end

    # A cluster's clusterable components.
    def cluster_components
      @cluster.holdings + @cluster.ht_items + @cluster.ocn_resolutions + @cluster.commitments
    end

    def recluster_components
      graph.subgraphs.each do |ocn_set|
        new_cluster = Cluster.where(ocns: {"$in": ocn_set}).first || Cluster.new(ocns: ocn_set)
        move_components(new_cluster.ht_items, @cluster.ht_items.where(ocns: {"$in": ocn_set}))
        move_components(new_cluster.holdings, @cluster.holdings.where(ocn: {"$in": ocn_set}))
        move_components(new_cluster.commitments,
          @cluster.commitments.where(ocn: {"$in": ocn_set}))
        move_components(new_cluster.ocn_resolutions,
          @cluster.ocn_resolutions.where(ocns: {"$in": ocn_set}))
        new_cluster.save
      end
    end

    def move_components(new_cluster_field, components)
      components&.each { |comp| new_cluster_field << comp }
    end
  end
end
