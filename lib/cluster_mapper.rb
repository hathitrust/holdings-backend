# frozen_string_literal: true

require "set"

# Map from identifiers (e.g. OCLC numbers) to a cluster of items identified as
# the same.
#
# Use the [] operator to get the cluster for a given identifier, for example:
# cluster = mapper[12345]
class ClusterMapper
  # Creates a ClusterMapper
  #
  # @param clusters The class to use for storing the clusters.
  def initialize(clusters)
    @clusters = clusters
  end

  # Add a member to a cluster. If member is already in another cluster, the two
  # clusters will be merged.
  #
  # @param id1, id2 The identifiers to associate together in the same cluster
  def add(id1, id2)
    if (old_cluster = clusters.find_by_member(id1))
      merge(self[id2], old_cluster)
    else
      self[id1].add(id2).save
    end
  end

  def [](id)
    clusters.find_by_member(id) || clusters.new(id)
  end

  private

  def merge(new, old)
    new.merge(old).save
    old.delete
  end

  attr_reader :clusters
end
