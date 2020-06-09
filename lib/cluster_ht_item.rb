# frozen_string_literal: true

require "cluster"

# Services for clustering HT Items
class ClusterHtItem
  # Creates a ClusterHTItem
  #
  # @param HTItem that needs clustering
  def initialize(ht_item)
    @ht_item = ht_item
  end

  # Cluster the HTItem
  def cluster
    c = (Cluster.merge_many(Cluster.where(ocns: { "$in": @ht_item.ocns })) ||
         Cluster.new(ocns: @ht_item.ocns).tap(&:save))
    c.ht_items << @ht_item
    c.ocns = c.ht_items.collect(&:ocns).flatten.uniq
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

end
