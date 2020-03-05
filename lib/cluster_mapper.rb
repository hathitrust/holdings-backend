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
  def initialize(clusters = Cluster, resolution = OCNResolution)
    @clusters = clusters
    @resolution = resolution
  end

  # Add an OCN resolution table entry
  #
  # @param ocn The deprecated OCN. If this OCN is already in
  # another cluster, the two clusters will be merged.
  #
  # @param resolved_ocn The resolved (a.k.a. master, current, terminal) OCN
  def add(ocn, resolved_ocn)
    resolved_cluster = find_or_make_cluster(resolved_ocn)

    if (old_cluster = find_cluster(ocn))
      resolved_cluster.merge(old_cluster)
    else
      resolved_cluster.ocns.append(ocn)
    end

    resolved_cluster.save

    resolution.new(deprecated: ocn, resolved: resolved_ocn).save
  end

  # Remove an OCN resolution table entry. After removing the resolution entry,
  # all resolution entries are examined to determine if the cluster should be
  # split, and if so, what OCNs belong in which new cluster.
  #
  # @param ocn The old deprecated OCN
  # @param resolved_ocn The old resolved (master, current, terminal) OCN
  #  def delete(ocn, resolved_ocn)
  #    resolution.find(ocn, resolved_ocn).delete
  #  end

  # Finds a cluster with the given id or makes a new cluster
  # if one does not exist.
  def [](ocn)
    find_or_make_cluster(ocn)
  end

  private

  def find_cluster(ocn)
    clusters.where(ocns: ocn).first
  end

  def find_or_make_cluster(ocn)
    find_cluster(ocn) || clusters.new(ocns: [ocn])
  end

  attr_reader :clusters, :resolution
end
