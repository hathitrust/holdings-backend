# frozen_string_literal: true

require "cluster"
require "ocn_resolution"

# Map from identifiers (e.g. OCLC numbers) to a cluster of items identified as
# the same.
#
# Use the [] operator to get the cluster for a given identifier, for example:
# cluster = mapper[12345]
class ClusterMapper
  # Creates a ClusterMapper
  #
  # @param clusters The class to use for storing the clusters.
  def initialize(clusters = Cluster, resolutions = OCNResolution)
    @clusters = clusters
    @resolutions = resolutions
  end

  # Add an OCN resolution table entry
  #
  # @param ocn The deprecated OCN. If this OCN is already in
  # another cluster, the two clusters will be merged.
  #
  # @param resolved_ocn The resolved (a.k.a. master, current, terminal) OCN
  def add(resolution)
    resolved_cluster = find_or_make_cluster(resolution.resolved)

    if (old_cluster = find_cluster(resolution.deprecated))
      resolved_cluster.merge(old_cluster)
    else
      resolved_cluster.ocns.append(resolution.deprecated)
    end

    resolved_cluster.save
    resolution.save
  end

  # Remove an OCN resolution table entry. After removing the resolution entry,
  # gather everything in the old cluster and re-load it to new clusters.
  #
  # @param ocn The old deprecated OCN
  # @param resolved_ocn The old resolved (master, current, terminal) OCN
  def delete(resolution)
    # there should only be one; need to verify that
    resolution.delete

    # there should only be one; need to verify that
    clusters.for_resolution(resolution).each do |cluster|
      cluster.delete
      add_resolutions(cluster)
    end
  end

  # Finds a cluster with the given id or makes a new cluster
  # if one does not exist.
  def [](ocn)
    find_or_make_cluster(ocn)
  end

  private

  def add_to_clusters(ocn, resolved_ocn); end

  def find_cluster(ocn)
    clusters.where(ocns: ocn).first
  end

  def find_or_make_cluster(ocn)
    find_cluster(ocn) || clusters.new(ocns: [ocn])
  end

  # Gather all resolution rules pertaining to this cluster and re-create
  # clusters
  def add_resolutions(cluster)
    resolutions.for_cluster(cluster).each do |resolution|
      add(resolution)
    end
  end

  attr_reader :clusters, :resolutions
end
