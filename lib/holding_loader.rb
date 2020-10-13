# frozen_string_literal: true

require "ht_item"
require "cluster_holding"

# Constructs batches of Holdings from incoming file data
class HoldingLoader
  def initialize(update: false)
    @organization = nil
    @current_date = nil
    @update = update
  end

  def item_from_line(line)
    Holding.new_from_holding_file_line(line).tap do |h|
      @organization ||= h.organization
      @current_date ||= h.date_received
    end
  end

  def load(batch)
    if @update
      ClusterHolding.new(batch).update
    else
      ClusterHolding.new(batch).cluster
    end
  end

  def finalize
    if @update
      ClusterHolding.delete_old_holdings(@organization, @current_date)
    end
  end
end
