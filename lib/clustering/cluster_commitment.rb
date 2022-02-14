# frozen_string_literal: true

require "cluster"
require "clustering/cluster_getter"

module Clustering
  # Services for batch loading Commitments
  class ClusterCommitment
    def initialize(*commitments)
      @commitments = commitments.flatten
      @ocn = @commitments.first.ocn
      @any_updated = false

      if @commitments.count > 1 && @commitments.any? { |c| !c.batch_with?(@commitments.first) }
        raise ArgumentError, "OCN for each Commitment in batch must match"
      end

      if @ocn.nil?
        raise ArgumentError, "Cannot cluster Commitment without an OCN"
      end

      if @commitments.pluck(:uuid).uniq.count < @commitments.count
        raise ArgumentError, "Cannot cluster multiple Commitments with the same UUID"
      end
    end

    def cluster(getter: ClusterGetter.new([@ocn]))
      getter.get do |c|
        to_add = []

        cluster_uuids = uuids_in_cluster(c)
        @commitments.each do |commitment|
          next if cluster_uuids.include? commitment.uuid

          to_add << commitment
        end
        c.add_commitments(to_add)
      end
    end

    def uuids_in_cluster(cluster)
      cluster.commitments.pluck(:uuid)
    end
  end
end
