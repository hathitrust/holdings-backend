# frozen_string_literal: true

require "cluster"
require "reclusterer"

# Services for batch loading HT items
class ClusterHtItem

  def initialize(ocns = [], transaction: true)
    @ocns = ocns
    @transaction = transaction
  end

  # Cluster the HTItem
  def cluster(batch)
    cluster_for_ocns.tap do |c|
      to_append = []
      batch.each do |item|
        if (existing_item = c.ht_item(item.item_id))
          existing_item.update_attributes(item.to_hash)
        else
          remove_old_ht_item(item)
          to_append << item
        end
      end
      c.ht_items.concat(to_append)
    end
  end

  # Move an HTItem from one cluster to another
  #
  # @param new_cluster - the cluster to move to
  def move(ht_item, new_cluster)
    unless new_cluster.id == ht_item._parent.id
      duped_htitem = ht_item.dup
      ht_item.delete
      new_cluster.ht_items << duped_htitem
      ht_item = duped_htitem
    end
  end

  # Removes an HTItem
  def delete(ht_item)
    Cluster.where("ht_items.item_id": ht_item.item_id).each do |c|
      c.ht_items.delete_if {|h| h.item_id == ht_item.item_id }
      Reclusterer.new(c).recluster
    end
  end

  private

  def remove_old_ht_item(ht_item)
    if (cluster = Cluster.with_ht_item(ht_item).first)
      cluster.ht_item(ht_item.item_id).delete

      # Note that technically we only need to do this if there were multiple
      # OCNs for that HT item and nothing else binds the cluster together.
      # It may be worth optimizing not to do this if the htitem has only one
      # OCN, since that will be the common case. Probably not worth checking
      # that nothing else binds the cluster together?
      Reclusterer.new(cluster).recluster
    end
  end

  def cluster_for_ocns
    existing_cluster_with_ocns || Cluster.create(ocns: @ocns)
  end

  def existing_cluster_with_ocns
    return unless @ocns.any?

    Cluster.merge_many(Cluster.for_ocns(@ocns),
                       transaction: @transaction).tap do |c|
                         c&.add_to_set(ocns: @ocns)
                       end
  end

end
