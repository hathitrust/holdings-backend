
# frozen_string_literal: true

require "cluster"
require "reclusterer"

# Services for batch loading HT items
class BatchClusterHtItem

  def initialize(ocns,transaction=false)
    @ocns = ocns
    @transaction = transaction
  end

  def cluster(batch)
    cluster_for_ocns.tap do |c|
      c.ht_items.append(*batch)
    end
  end

  private

  def cluster_for_ocns
    existing_cluster_with_ocns || Cluster.create(ocns: @ocns)
  end

  def existing_cluster_with_ocns
    return unless @ocns.any?
    Cluster.merge_many(Cluster.for_ocns(@ocns), transaction: @transaction)
  end

end
