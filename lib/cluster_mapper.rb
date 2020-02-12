# frozen_string_literal: true

require "set"

# Map from identifiers (e.g. OCLC numbers) to a cluster of items identified as
# the same.
#
# Use the [] operator to get the cluster for a given identifier, for example:
# cluster = mapper[12345]
class ClusterMapper
  extend Forwardable

  def_delegators :clusters, :[]

  # Creates a ClusterMapper
  #
  # @param clusters The back-end to use for storing the clusters. By default
  # uses an in-memory hash. Must respond to [] and auto-vivify new clusters.
  def initialize(clusters = Hash.new {|hash, id| hash[id] = Cluster.new(id) })
    @clusters = clusters
  end

  # Add a member to a cluster. If member is already in another cluster, the two
  # clusters will be merged.
  #
  # @param id The identifier of the cluster to add to
  # @param member The identifier of the item to add to the cluster
  def add(id, member)
    new_cluster = self[id]
    old_cluster = self[member]

    new_cluster.merge(old_cluster)
    old_cluster.each do |old_member|
      @clusters[old_member] = new_cluster
    end
  end

  private

  attr_reader :clusters
end
