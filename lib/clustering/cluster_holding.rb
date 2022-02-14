# frozen_string_literal: true

require "cluster"
require "clustering/cluster_getter"

module Clustering
  # Services for clustering Print Holdings records
  class ClusterHolding
    def initialize(*holdings)
      @holdings = holdings.flatten
      raise ArgumentError, "Must have holdings to cluster" unless @holdings.any?

      @ocn = @holdings.first.ocn
      @any_updated = false

      if @holdings.count > 1 && @holdings.any? { |h| !h.batch_with?(@holdings.first) }
        raise ArgumentError, "OCN for each holding in batch must match"
      end

      raise ArgumentError, "Holding must have exactly one OCN" if @ocn.nil?
    end

    # Updates a matching holding or adds it
    def cluster(getter: ClusterGetter.new([@ocn]))
      getter.get do |c|
        to_add = []

        common_uuids = check_for_duplicate_uuids!(c.holdings.to_a, @holdings)
        @holdings.each do |holding|
          next if common_uuids.include? holding.uuid

          old_holdings = find_old_holdings(c, holding)
          if old_holdings.any?
            old_holdings.each { |old| update_holding(old, holding) }
          elsif duplicate_large_cluster_holding? c, holding, to_add
            next
          else
            to_add << holding
          end
        end
        c.add_holdings(to_add)
      end
    end

    def delete
      raise ArgumentError, "Can only delete one holding at a time" unless @holdings.length == 1

      holding = @holdings.first

      Retryable.new.run do
        c = Cluster.find_by(ocns: holding.ocn)
        holding.delete
        c.save
        c.reload
        c.delete unless c._children.any?
      end
    end

    def self.delete_old_holdings(org, date)
      Cluster.where(
        "holdings.organization": org,
        "holdings.date_received": {"$lt": date}
      ).each do |c|
        c.holdings
          .select { |h| h.organization == org && h.date_received < date }
          .map { |h| ClusterHolding.new(h).delete }
      end
    end

    private

    def update_holding(old, new)
      old.update_attributes(date_received: new.date_received,
        uuid: new.uuid)
    end

    def find_old_holdings(cluster, holding)
      if cluster.large?
        cluster.holdings.to_a.select do |h|
          h.organization == holding.organization && h.date_received != holding.date_received
        end
      else
        # Build a fast lookup for holdings
        # {update_key1: h1, update_key2: h2, ...}
        @cluster_holdings_lookup ||= cluster.holdings.group_by(&:update_key)
        [
          @cluster_holdings_lookup[holding.update_key]&.find do |h|
            h.date_received != holding.date_received
          end
        ]
      end
    end

    def duplicate_large_cluster_holding?(cluster, holding, to_add)
      cluster.large? &&
        (cluster.holdings.to_a.find { |h| h.organization == holding.organization } ||
         to_add.find { |h| h.organization == holding.organization })
    end

    # Check and see if any items across existing/new holdings share a UUID but no other attributes.
    # Assumes uuids will not be duplicated within either list
    # Common case is that there is no overlap
    def check_for_duplicate_uuids!(existing_holdings, new_holdings)
      existing_by_uuid = existing_holdings.group_by(&:uuid)
      new_by_uuid = new_holdings.group_by(&:uuid)
      common_uuids = existing_by_uuid.keys & new_by_uuid.keys

      common_uuids.each do |uuid|
        existing = existing_by_uuid[uuid]
        new_holding = new_by_uuid[uuid]

        unless existing.length == 1
          raise "There should be EXACTLY one holding with that UUID #{uuid}"
        end

        unless new_holding.length == 1
          raise "There should be EXACTLY one holding with that UUID #{uuid}"
        end

        unless existing.first.same_as?(new_holding.first)
          raise "Found holding #{existing.first.inspect} with same UUID " \
                  "but different attributes from update #{new_holding.first.inspect}"
        end
      end
    end
  end
end
