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
    @cluster.with_session do |session|
      session.start_transaction
      @cluster.delete

      @cluster.ocn_resolutions.each {|r| ClusterOCNResolution.new(r).cluster(transaction: false).save }
      @cluster.holdings.each {|h| ClusterHolding.new(h).cluster(transaction: false).save }
      @cluster.ht_items.each {|h| ClusterHtItem.new(h).cluster(transaction: false).save }
      @cluster.serials.each {|s| ClusterSerial.new(s).cluster(transaction: false).save }
      session.commit_transaction
    end
    # TODO ClusterCommitment
  end

end
