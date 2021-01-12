# frozen_string_literal: true

require "cluster"
require "cluster_getter"

# Services for clustering Print Holdings records
class ClusterHolding

  def initialize(*holdings)
    @holdings = holdings.flatten
    @ocn = @holdings.first.ocn

    if @holdings.count > 1 && @holdings.any? {|h| !h.batch_with?(@holdings.first) }
      raise ArgumentError, "OCN for each holding in batch must match"
    end

    raise ArgumentError, "Holding must have exactly one OCN" if @ocn.nil?
  end

  # Updates a matching holding or adds it
  def cluster(getter: ClusterGetter.new([@ocn]))
    getter.get do |c|
      to_add = []

      @holdings.each do |holding|
        if (existing = c.holdings.to_a.find {|h| h.uuid == holding.uuid })
          next if existing.same_as?(holding)

          raise "Found holding #{existing.inspect} with same UUID " \
            "but different attributes from update #{holding.inspect}"
        end

        old_holdings = find_old_holdings(c, holding)

        if old_holdings.any?
          old_holdings.each {|old| update_holding(old, holding) }
        elsif duplicate_large_cluster_holding? c, holding, to_add
          next
        else
          to_add << holding
        end
      end

      c.add_holdings(to_add)
    end
  end
  alias_method :update, :cluster

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
      [cluster.holdings.to_a.find {|h| h == holding && h.date_received != holding.date_received }]
    end
  end

  def duplicate_large_cluster_holding?(cluster, holding, to_add)
    cluster.large? &&
      (cluster.holdings.to_a.find {|h| h.organization == holding.organization } ||
       to_add.find {|h| h.organization == holding.organization })
  end

end
