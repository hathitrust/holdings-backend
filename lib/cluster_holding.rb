# frozen_string_literal: true

require "cluster"

# Services for clustering Print Holdings records
class ClusterHolding
  def initialize(*holdings)
    @holdings = holdings.flatten
    @ocns= [@holdings.first.ocn]
    @holding = @holdings.first

    if @holdings.find {|h| h.ocn != @ocns.first }
      raise ArgumentError, "OCN for each holding in batch must match"
    end

    if (@ocns.nil? || @ocns.empty?) && @holdings.length > 1
      raise ArgumentError, "Cannot cluster multiple OCN-less holdings"
    end
  end

  def cluster
    Retryable.new.run do
      cluster_for_ocns.tap do |cluster|
        Services.logger.debug "adding holdings #{@holdings.inspect} "\
          " with ocn #{@ocns} to cluster #{cluster.inspect}"
        cluster.add_holdings(@holdings)
      end
    end
  end

  def move(new_cluster)
    raise ArgumentError, "Can only move one holding at a time" unless @holdings.length == 1

    holding = @holdings.first

    Retryable.with_transaction do
      unless new_cluster.id == holding._parent.id
        duped_h = holding.dup
        new_cluster.add_holdings(duped_h)
        holding.delete
        holding = duped_h
      end
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

  private

  attr_reader :htitems, :ocns

  def cluster_for_ocns
    Cluster.for_ocns(@ocns).first || Cluster.create(ocns: @ocns)
  end

end
