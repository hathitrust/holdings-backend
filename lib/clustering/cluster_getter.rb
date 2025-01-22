# frozen_string_literal: true

require "cluster"

module Clustering
  # This class provides a Cluster that contains all the given OCNs. Thus,
  # a call to ClusterGetter.get(@ocns) effectively says: these OCNs belong
  # together in a cluster.
  #
  # TODO: consider renaming to ClusterOCNs.cluster(@ocns)?
  #
  # If some cluster exists that has at least some of the requested OCNs:
  # - Add any other OCNs not in any cluster yet to that cluster
  # - Merge other clusters containing some of these OCNs with that cluster
  #
  # Otherwise:
  # - Make a new cluster with the OCNs
  class ClusterGetter
    def initialize(ocns)
      @ocns = ocns
    end

    # @return A single cluster that contains all the requested OCNs,
    # or nil if no OCNs were provided.
    #
    # Finds an existing cluster with some of the OCNs, then adds the other OCNs
    # to it, or creates a new cluster if none of the OCNs are in any existing
    # cluster.
    #
    # If the cluster for these OCNs was modified by another process while our
    # transaction is in process (raising a duplicate key error), retries the
    # entire operation, possibly using another strategy.
    #
    # ClusterGetter.new(ocns).get ensures that ocns are all in the *same
    # cluster*, but can't guarantee that that cluster isn't modified elsewhere.
    # Take care if using the returned cluster ID or OCNs.
    def get
      Services[:holdings_db].transaction(**transaction_opts) do
        find_or_create.tap { |c| yield c if block_given? }
      end
    end

    private

    def transaction_opts
      {retry_on: [Sequel::UniqueConstraintViolation]}
    end

    def find_or_create
      return unless @ocns.any?

      clusters = find

      if clusters.none?
        create
      else
        clusters.first.tap do |target_cluster|
          add_additional_ocns(target_cluster, clusters)
          merge(target_cluster, clusters) if clusters.count > 1
        end
      end
    end

    def find
      Cluster.for_ocns(@ocns).to_a
    end

    def create
      Cluster.create(ocns: @ocns)
    end

    def add_additional_ocns(target_cluster, clusters)
      # OCNs (from the ones we want) that are in any cluster
      attested_ocns = clusters.collect(&:ocns).reduce(&:merge)
      # OCNs that are not in any cluster
      additional_ocns = @ocns.to_set - attested_ocns

      target_cluster.add_ocns(additional_ocns)
    end

    # Merges OCNs for all the given clusters into the target cluster.
    def merge(target_cluster, clusters)
      raise "merge: not implemented"
      Retryable.ensure_transaction do
        @clusters.each do |source|
          raise ClusterError, "clusters disappeared, try again" if source.nil?
          next if source._id == @target._id

          # Boolean xor. One and only one is "large"
          if source.large? ^ @target.large?
            warn("Merging into a large cluster. " \
                  "OCNs: [#{source.ocns.join(",")}] and [#{@target.ocns.join(",")}]")
          end

          source.delete
          @target.add_members_from(source)
          @target.add_to_set(ocns: source.ocns)
          Services.logger.debug "Deleted cluster #{source.inspect} (merged into #{@target.inspect})"
        end
        @target.add_to_set(ocns: @ocns)
      end
    end
  end
end
