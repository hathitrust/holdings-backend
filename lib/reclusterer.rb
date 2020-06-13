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
    @cluster.delete

    @cluster.ocn_resolutions.each {|r| ClusterOCNResolution.new(r).cluster.save }
    @cluster.holdings.each {|h| ClusterHolding.new(h).cluster.save }
    @cluster.ht_items.each {|h| ClusterHtItem.new(h).cluster.save }
    @cluster.serials.each {|s| ClusterSerial.new(s).cluster.save }
    # TODO ClusterCommitment
  end

end
