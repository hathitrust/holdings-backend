# frozen_string_literal: true

require "cluster"

# Deletes a cluster, then re-creates clusters from the data in that cluster.
# Use after changing data in a cluster that could affect which items are in the
# cluster.
class Reclusterer

  def initialize(cluster)
    @cluster = cluster
  end

  def recluster
    Cluster.with_transaction do
      Services.logger.debug "Deleting and reclustering cluster #{@cluster.inspect}"
      @cluster.delete

      recluster_components
    end
  end

  private

  def recluster_components
    @cluster.ocn_resolutions.each {|r| ClusterOCNResolution.new(r.dup).cluster.save }
    @cluster.holdings.each {|h| ClusterHolding.new(h.dup).cluster.save }
    # TODO: group and batch by OCN
    @cluster.ht_items.each {|h| ClusterHtItem.new(h.dup).cluster.save }
    @cluster.serials.each {|s| ClusterSerial.new(s.dup).cluster.save }
  end

end
