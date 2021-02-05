# frozen_string_literal: true

require "cluster"
require "reclusterer"
require "cluster_getter"
require "retryable"

# Services for batch loading HT items
class ClusterHtItem

  def initialize(*ht_items)
    @ht_items = ht_items.flatten
    @ocns = @ht_items.first.ocns

    if @ht_items.count > 1 && @ht_items.any? {|h| !h.batch_with?(@ht_items.first) }
      raise ArgumentError, "OCN for each HTItem in batch must match"
    end

    if (@ocns.nil? || @ocns.empty?) && @ht_items.length > 1
      raise ArgumentError, "Cannot cluster multiple OCN-less HTItems"
    end
  end

  def cluster(getter: ClusterGetter.new(@ocns))
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
        cluster.ht_item(ht_item.item_id).delete

        # Note that technically we only need to do this if there were multiple
        # OCNs for that HT item and nothing else binds the cluster together.
        # It may be worth optimizing not to do this if the htitem has only
        # one OCN, since that will be the common case. Not sure if it's worth
        # optimizing away if there are multiple OCNs (i.e. doing the check to
        # see if anything else binds the cluster together). In general the
        # operation is probably rare enough that we don't need to worry about
        # this for the time being.
        Reclusterer.new(cluster).recluster
      end
    end
  end

  private

  attr_reader :ht_items, :ocns

  def cluster_with_htitem(htitem)
    Cluster.with_ht_item(htitem).first
  end

  def update_or_add_ht_items(cluster)
    Services.logger.debug "Cluster #{cluster.inspect}: " \
      "adding ht_items #{ht_items.inspect} with ocns #{@ocns}"
    to_append = []
    needs_reclustering = false
    ht_items.each do |item|
      if (existing_item = cluster.ht_item(item.item_id))
        Services.logger.debug "updating existing item with id #{item.item_id}"
        needs_reclustering = true unless current_is_subset_of_new(existing_item.ocns, item.ocns)
        existing_item.update_attributes(item.to_hash)
      else
        ClusterHtItem.new(item).delete
        to_append << item
      end
    end

    cluster.add_ht_items(to_append) unless to_append.empty?

    Reclusterer.new(cluster).recluster if needs_reclustering
  end

  def current_is_subset_of_new(current_ocns, new_ocns)
    current_ocns & new_ocns == current_ocns
  end

end
