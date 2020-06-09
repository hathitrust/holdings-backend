# frozen_string_literal: true

require "cluster"
require "reclusterer"

# Services for clustering OCN Resolutions
class ClusterOCNResolution
  # Creates a ClusterOCNResolution
  #
  # @param OCNResolution that needs clustering
  def initialize(resolution)
    @resolution = resolution
  end

  # Cluster the OCNResolution
  def cluster
    c = (Cluster.merge_many(Cluster.where(ocns: { "$in": @resolution.ocns })) ||
         Cluster.new(ocns: @resolution.ocns).tap(&:save))
    c.ocn_resolutions << @resolution
    c.ocns = c.collect_ocns
    c
  end

  # Move an OCN resolution rule from one cluster to another
  #
  # @param new_cluster - the cluster to move to
  def move(new_cluster)
    unless new_cluster.id == @resolution._parent.id
      duped_resolution = @resolution.dup
      @resolution.delete
      new_cluster.ocn_resolutions << duped_resolution
      @resolution = duped_resolution
      new_cluster.ocns = new_cluster.collect_ocns
    end
  end

  def delete
    Cluster.where(ocns: { "$all": @resolution.ocns }).each do |c|
      had_resolution = false

      c.ocn_resolutions.delete_if do |candidate|
        candidate.deprecated == @resolution.deprecated &&
          candidate.resolved == @resolution.resolved &&
          had_resolution = true
      end

      if had_resolution
        Reclusterer.new(c).recluster
      end
    end
  end

end
