# frozen_string_literal: true

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

  def cluster
    ClusterGetter.for([@ocn]) do |cluster|
      cluster.add_holdings(@holdings)
    end
  end

  # Updates a matching holding or adds it
  def update
    # TODO retryable etc.
    @holding = @holdings.first

    c = Cluster.find_by(ocns: [@holding.ocn])
    return cluster unless c

    old_holding = c.holdings.to_a.find do |h|
      h == @holding && h.date_received != @holding.date_received
    end
    if old_holding
      old_holding.update_attributes(date_received: @holding.date_received)
    else
      c = cluster
    end
    c
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
