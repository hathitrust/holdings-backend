# frozen_string_literal: true

require "cluster"
require "reclusterer"
require "cluster_error"
require "retryable"

# Services for batch loading HT items
class ClusterHtItem

  def initialize(*htitems)
    @htitems = htitems.flatten
    @ocns = @htitems.first.ocns

    if @htitems.find {|h| h.ocns != @ocns }
      raise ArgumentError, "OCNs for each HTItem in batch must match"
    end

    if (@ocns.nil? || @ocns.empty?) && @htitems.length > 1
      raise ArgumentError, "Cannot cluster multiple OCN-less HTItems"
    end
  end

  def cluster
    Retryable.new.run do
      cluster_for_ocns.tap do |cluster|
        Services.logger.debug "adding htitems #{htitems.inspect} " \
          " with ocns #{@ocns} to cluster #{cluster.inspect}"
        update_or_add_htitems(cluster, htitems)
      end
    end
  end

  # Move HTItem from one cluster to another
  #
  # @param new_cluster - the cluster to move to
  def move(new_cluster)
    raise ArgumentError, "Can only move one HTItem at a time" unless htitems.length == 1

    ht_item = htitems.first
    return if new_cluster.id == ht_item._parent.id

    Retryable.with_transaction do
      duped_htitem = ht_item.dup
      ht_item.delete
      new_cluster.add_ht_items(duped_htitem)
    end
  end

  # Removes an HTItem
  def delete
    raise ArgumentError, "Can only delete one HTItem at a time" unless htitems.length == 1

    ht_item = htitems.first
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

  attr_reader :htitems, :ocns

  def cluster_with_htitem(htitem)
    Cluster.with_ht_item(htitem).first
  end

  def cluster_for_ocns
    existing_cluster_with_ocns || Cluster.create(ocns: @ocns)
  end

  def existing_cluster_with_ocns
    return unless @ocns.any?

    Cluster.merge_many(Cluster.for_ocns(@ocns)).tap do |c|
      c&.add_to_set(ocns: @ocns)
    end
  end

  def update_or_add_htitems(cluster, htitems)
    Services.logger.debug "Cluster #{cluster.inspect}: " \
      "adding htitems #{htitems.inspect} with ocns #{@ocns}"
    to_append = []
    htitems.each do |item|
      if (existing_item = cluster.ht_item(item.item_id))
        Services.logger.debug "updating existing item with id #{item.item_id}"
        existing_item.update_attributes(item.to_hash)
      else
        ClusterHtItem.new(item).delete
        to_append << item
      end
    end

    unless to_append.empty?
      cluster.add_ht_items(to_append)
    end
  end

end
