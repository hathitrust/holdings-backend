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

end
