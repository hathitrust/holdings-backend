# frozen_string_literal: true

require "cluster"
require "clustering/cluster_ocn_resolution"
require "clustering/cluster_holding"
require "clustering/cluster_ht_item"
require "clustering/cluster_commitment"

module Clustering
  # Deletes a cluster, then re-creates clusters from the data in that cluster.
  # Use after changing data in a cluster that could affect which items are in the
  # cluster.
  class Reclusterer

    def initialize(cluster)
      @cluster = cluster
    end

    def recluster
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

    private

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
