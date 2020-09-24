# frozen_string_literal: true

require "cluster"
require "reclusterer"
require "cluster_getter"

# Services for clustering OCN Resolutions
class ClusterOCNResolution

  def initialize(*resolutions)
    @resolutions = resolutions.flatten
    resolved = @resolutions.first.resolved
    @ocns = @resolutions.map(&:ocns).flatten.uniq

    if @resolutions.find {|c| c.resolved != resolved }
      raise ArgumentError, "Resolved OCNs for each OCN resolution rule in batch must match"
    end
  end

  # Cluster the OCNResolution
  def cluster
    ClusterGetter.for(@ocns) do |cluster|
      update_or_add_resolutions(cluster)
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

  def update_or_add_resolutions(cluster)
    to_add = []
    @resolutions.each do |r|
      to_add << r unless cluster.ocn_resolutions.any? {|existing| r == existing }
    end
    cluster.add_ocn_resolutions(to_add)
  end

end
