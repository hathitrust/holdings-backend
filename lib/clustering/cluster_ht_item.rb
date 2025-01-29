# frozen_string_literal: true

require "cluster"
require "clustering/reclusterer"

module Clustering
  # Services for batch loading HT items
  class ClusterHtItem
    def initialize(*ht_items)
      @ht_items = ht_items.flatten
      @ocns = @ht_items.first.ocns
      @any_updated = false

      if @ht_items.count > 1 && @ht_items.any? { |h| !h.batch_with?(@ht_items.first) }
        raise ArgumentError, "OCN for each HTItem in batch must match"
      end

      if (@ocns.nil? || @ocns.empty?) && @ht_items.length > 1
        raise ArgumentError, "Cannot cluster multiple OCN-less HTItems"
      end
    end

    def cluster
      return if ocns.empty?

      # Right now, we aren't persisting anything except ensuring that the OCNs
      # for the htitem are in the same cluster
      Cluster.cluster_ocns!(ocns)
    end

    private

    attr_reader :ht_items, :ocns
  end
end
