# frozen_string_literal: true

require "cluster"

# Services for clustering Print Holdings records
class ClusterHolding
  def initialize(holding)
    @holding = holding
  end

  def cluster
    c = (Cluster.find_by(ocns: @holding[:ocn]) ||
         Cluster.new(ocns: [@holding[:ocn]]).tap(&:save))
    c.holdings << @holding
    c
  end

  def move(new_cluster)
    unless new_cluster.id == @holding._parent.id
      duped_h = @holding.dup
      new_cluster.holdings << duped_h
      @holding.delete
      @holding = duped_h
    end
  end

  # Updates a matching holding or adds it
  def update
    c = Cluster.find_by(ocns: @holding.ocn)
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
    c = Cluster.find_by(ocns: @holding.ocn)
    @holding.delete
    c.save
    c.reload
    c.delete unless c._children.any?
  end

  def self.delete_old_holdings(org, date)
    Cluster.where(
      "holdings.organization": org,
      "holdings.date_received": { "$lt": date }
    ).each do |c|
      c.holdings.select do |h|
        h.organization == org && h.date_received < date
      end.map {|h| ClusterHolding.new(h).delete }
    end
  end

end
