# frozen_string_literal: true

require "cluster"
require "clustering/reclusterer"
require "clustering/cluster_getter"

module Clustering
  # Services for clustering OCN Resolutions
  class ClusterOCNResolution
    def initialize(*resolutions)
      @resolutions = resolutions.flatten
      @ocns = @resolutions.map(&:ocns).flatten.uniq

      if @resolutions.count > 1 && @resolutions.any? { |r| !r.batch_with?(@resolutions.first) }
        raise ArgumentError, "Resolved OCNs for each OCN resolution rule in batch must match"
      end
    end

    def cluster(getter: ClusterGetter.new(@ocns))
      getter.get do |cluster|
        add_resolutions(cluster)
      end
    end

    def delete
      raise ArgumentError, "Can only delete one resolution at a time" unless @resolutions.count == 1

      resolution = @resolutions.first
      return unless Cluster.where(ocns: {"$all": resolution.ocns}).any?

      Retryable.with_transaction do
        Cluster.where(ocns: {"$all": resolution.ocns}).each do |c|
          c.ocn_resolutions.delete_if do |candidate|
            candidate.deprecated == resolution.deprecated &&
              candidate.resolved == resolution.resolved
          end
          Reclusterer.new(c, resolution.ocns).recluster
        end
      end
    end

    private

    def add_resolutions(cluster)
      to_add = @resolutions.reject { |r| cluster.ocn_resolutions.include? r }
      cluster.add_ocn_resolutions(to_add)
    end
  end
end
