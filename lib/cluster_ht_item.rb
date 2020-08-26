# frozen_string_literal: true

require "cluster"
require "reclusterer"

# Services for clustering HT Items
class ClusterHtItem
  # Creates a ClusterHTItem
  #
  # @param HTItem that needs clustering
  def initialize(ht_item)
    @ht_item = ht_item
  end

  # Cluster the HTItem
  def cluster(transaction: true)
    c = (@ht_item.ocns.any? &&
         Cluster.merge_many(Cluster.where(ocns: { "$in": @ht_item.ocns }),transaction: transaction) ||
         Cluster.new(ocns: @ht_item.ocns).tap(&:save))
    c.ht_items << @ht_item
    @ht_item.ocns.each do |ocn|
      c.ocns << ocn unless c.ocns.include?(ocn)
    end
    c
  end

  # Move an HTItem from one cluster to another
  #
  # @param new_cluster - the cluster to move to
  def move(new_cluster)
    unless new_cluster.id == @ht_item._parent.id
      duped_htitem = @ht_item.dup
      @ht_item.delete
      new_cluster.ht_items << duped_htitem
      @ht_item = duped_htitem
    end
  end

  # Removes an HTItem
  def delete
    Cluster.where("ht_items.item_id": @ht_item.item_id).each do |c|
      c.ht_items.delete_if {|h| h.item_id == @ht_item.item_id }
      Reclusterer.new(c).recluster
    end
  end

  # Deletes an HTItem, then re-adds it
  def update
    Cluster.where("ht_items.item_id": @ht_item.item_id).each do |c|
      ht = c.ht_items.to_a.find {|h| h.item_id == @ht_item.item_id }
      if ht.ocns != @ht_item.ocns
        ht.delete
        Reclusterer.new(c).recluster
      else
        ht.update_attributes(@ht_item.to_hash)
        c.save
        return c
      end
    end
    cluster
  end
end
