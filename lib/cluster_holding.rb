# frozen_string_literal: true

require "spec_helper"
require "cluster"
require "cluster_getter"

# Services for clustering Print Holdings records
class ClusterHolding

  def initialize(*holdings)
    @holdings = holdings.flatten
    @ocn = @holdings.first.ocn

    if @holdings.find {|c| c.ocn != @ocn }
      raise ArgumentError, "OCN for each holding in batch must match"
    end

    raise ArgumentError, "Holding must have exactly one OCN" if @ocn.nil?
  end

  def cluster(getter: ClusterGetter.new([@ocn]))
    getter.get do |cluster|
      cluster.add_holdings(@holdings)
    end
  end

  # Updates a matching holding or adds it
  def update(getter: ClusterGetter.new([@ocn]))
    getter.get do |c|
      to_add = []

      @holdings.each do |holding|
        if (existing = c.holdings.to_a.find {|h| h.uuid == holding.uuid })
          next if existing.same_as?(holding)

          raise "Found holding #{existing} with same UUID " \
            "but different attributes from update #{holding}"
        end

        old_holding = c.holdings.to_a.find do |h|
          h == holding && h.date_received != holding.date_received
        end

        if old_holding
          old_holding.update_attributes(date_received: holding.date_received, uuid: holding.uuid)
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
      "holdings.date_received": { "$lt": date }
    ).each do |c|
      c.holdings
        .select {|h| h.organization == org && h.date_received < date }
        .map {|h| ClusterHolding.new(h).delete }
    end
  end

end
