# frozen_string_literal: true

require "cluster"
require "reclusterer"

# Services for clustering OCN Resolutions
class ClusterOCNResolution
  # Creates a ClusterOCNResolution
  #
  # @param OCNResolution that needs clustering
  def initialize(*resolutions)
    @resolutions = resolutions.flatten
    @ocns = @resolutions.first.ocns

    if @resolutions.find {|r| r.ocns != @ocns }
      raise ArgumentError, "OCNs for each OCNResolution in batch must match"
    end
  end

  # Cluster the OCNResolution
  def cluster
    Retryable.new.run do
      cluster_for_ocns.tap do |cluster|
        cluster.add_ocn_resolutions(@resolutions)

        ocns_to_add = @resolutions.map(&:ocns)
          .flatten.uniq.reject {|ocn| cluster.ocns.include?(ocn) }

        cluster.add_ocns(ocns_to_add) unless ocns_to_add.empty?
      end
    end
  end

  # Move an OCN resolution rule from one cluster to another
  #
  # @param new_cluster - the cluster to move to
  def move(new_cluster)
    raise ArgumentError, "Can only move one resolution at a time" unless @resolutions.length == 1

    resolution = @resolutions.first
    return if new_cluster.id == resolution._parent.id

    Retryable.with_transaction do
      duped_resolution = resolution.dup
      resolution.delete
      new_cluster.add_ocn_resolutions(duped_resolution)
      resolution = duped_resolution
      new_cluster.ocns = new_cluster.collect_ocns
    end
  end

  def delete
    raise ArgumentError, "Can only delete one resolution at a time" unless @resolutions.length == 1

    resolution = @resolutions.first
    return unless Cluster.where(ocns: { "$all": resolution.ocns }).any?

    Retryable.with_transaction do
      Cluster.where(ocns: { "$all": resolution.ocns }).each do |c|
        had_resolution = false

        c.ocn_resolutions.delete_if do |candidate|
          candidate.deprecated == resolution.deprecated &&
            candidate.resolved == resolution.resolved &&
            had_resolution = true
        end

        if had_resolution
          Reclusterer.new(c).recluster
        end
      end
    end
  end

  def cluster_for_ocns
    existing_cluster_with_ocns || Cluster.create(ocns: @ocns)
  end

  def existing_cluster_with_ocns
    return unless @ocns.any?

    Cluster.merge_many(Cluster.for_ocns(@ocns)).tap do |c|
      c&.add_to_set(ocns: @ocns)
    end
  end

end
