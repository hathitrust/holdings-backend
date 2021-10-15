# frozen_string_literal: true

require "services"
require "overlap/cluster_overlap"

# Update DB's overlap records for every ht_item and organization in a given cluster
class ClusterUpdate
  attr_accessor :cluster

  def initialize(overlap_table, cluster)
    @overlap_table = overlap_table
    @cluster = cluster
  end

  def deletes
    @deletes ||= (existing_overlaps - new_overlaps)
  end

  def adds
    @adds ||= (new_overlaps - existing_overlaps)
  end

  def new_overlaps
    if @new_overlaps
      return @new_overlaps
    else
      @new_overlaps = Overlap::ClusterOverlap.new(cluster, nil).each.to_a.map(&:to_hash)
    end

    @new_overlaps ||= []
  end

  # Overlaps for ht_items currently in the cluster
  # We will not find overlaps for items that have moved to another cluster,
  # those will be deleted when the other cluster adds their new overlaps.
  def existing_overlaps
    @existing_overlaps ||= cluster.ht_items.map do |ht_item|
      @overlap_table.filter(volume_id: ht_item.item_id).map(&:to_hash)
    end.flatten
  end

  def upsert
    Services.holdings_db.transaction do
      deletes.each do |rec|
        @overlap_table.filter(volume_id: rec[:volume_id], member_id: rec[:member_id]).delete
      end
      adds.each do |rec|
        @overlap_table.insert(rec.to_hash)
      end
    end
  end

end
