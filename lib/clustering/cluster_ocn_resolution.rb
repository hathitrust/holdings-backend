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

      if @resolutions.count > 1 && @resolutions.any? {|r| !r.batch_with?(@resolutions.first) }
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

    def needs_recluster?(cluster, resolution)
      # We only need to recluster if the resolution could have been the 'glue' holding multiple
      # OCNs together. The following situations mean the Resolution cannot be glue, so we don't
      # need to recluster:
      # 
      # - There is an HTItem with the same pair of OCNs.
      # - The cluster's Items, Holdings, and Commitments have the same OCN and any other resolutions contain that OCN.
      # - The pair can be derived by transitivity of other Resolutions/Items

      return true
    end
      
    private

    def add_resolutions(cluster)
      to_add = @resolutions.reject {|r| cluster.ocn_resolutions.include? r }
      cluster.add_ocn_resolutions(to_add)
    end

  end
end
