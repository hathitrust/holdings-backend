# frozen_string_literal: true

require "cluster"
require "clustering/reclusterer"
require "clustering/cluster_getter"
require "clustering/ht_item_cluster_getter"
require "clustering/retryable"
require "set"

module Clustering
  # Services for batch loading HT items
  class ClusterHtItem

    def initialize(*ht_items)
      @ht_items = ht_items.flatten
      @ocns = @ht_items.first.ocns
      @any_updated = false

      if @ht_items.count > 1 && @ht_items.any? {|h| !h.batch_with?(@ht_items.first) }
        raise ArgumentError, "OCN for each HTItem in batch must match"
      end

      if (@ocns.nil? || @ocns.empty?) && @ht_items.length > 1
        raise ArgumentError, "Cannot cluster multiple OCN-less HTItems"
      end
    end

    def cluster(getter: cluster_getter)
      # For the case where there are no OCNs, ClusterGetter always creates a new
      # cluster. We might want to first consider searching by item ID when there
      # are no OCNs.

      getter.get do |cluster|
        update_or_add_ht_items(cluster)
      end
    end

    # Removes an HTItem
    def delete
      raise ArgumentError, "Can only delete one HTItem at a time" unless ht_items.length == 1

      ht_item = ht_items.first
      # Don't start a transaction until we know there's something we need to
      # delete. If we do need to delete the thing, then we need to re-fetch it so
      # we can acquire the correct lock
      return unless cluster_with_htitem(ht_item)

      Retryable.with_transaction do
        if (cluster = cluster_with_htitem(ht_item))
          Services.logger.debug "removing old htitem #{ht_item.item_id}"
          old_item = cluster.ht_item(ht_item.item_id)
          old_item.delete

          Reclusterer.new(cluster, old_item.ocns).recluster
        end
      end
    end

    private

    attr_reader :ht_items, :ocns

    def cluster_getter
      if ocns.empty?
        Clustering::HtItemClusterGetter.new(*ht_items)
      else
        ClusterGetter.new(ocns)
      end
    end

    def cluster_with_htitem(htitem)
      Cluster.with_ht_item(htitem).first
    end

    def update_or_add_ht_items(cluster)
      Services.logger.debug "Cluster #{cluster.inspect}: " \
        "adding ht_items #{ht_items.inspect} with ocns #{ocns}"
      to_append = []
      ht_items.each do |item|
        if (existing_item = cluster.ht_item(item.item_id))
          Services.logger.debug "updating existing item with id #{item.item_id}"

          if (item_attrs = item.to_hash) != existing_item.to_hash
            existing_item.update_attributes(item_attrs)
            @any_updated = true
          end
        else
          ClusterHtItem.new(item).delete
          to_append << item
        end
      end

      cluster.add_ht_items(to_append) unless to_append.empty?
      if @any_updated || to_append.any?
        # Reclusterer would handle this if we could tell it which tuples were removed.
        cluster.update_ocns
        cluster.save
        Reclusterer.new(cluster).recluster
      end
    end

  end
end
