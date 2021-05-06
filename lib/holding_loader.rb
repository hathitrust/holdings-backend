# frozen_string_literal: true

require "ht_item"
require "cluster_holding"

# Constructs batches of Holdings from incoming file data
class HoldingLoader

  def self.get_for(filename)
    if filename.end_with?(".tsv")
      HoldingLoaderTsv.new
    elsif filename.end_with?(".ndj")
      HoldingLoaderNdj.new
    else
      raise "given an invalid file extension"
    end
  end

  def initialize
    @organization = nil
    @current_date = nil
  end

  def item_from_line(_line)
    raise "override me"
  end

  def load(batch)
    ClusterHolding.new(batch).cluster
  end

  def finalize
    if @update
      ClusterHolding.delete_old_holdings(@organization, @current_date)
    end
  end
end

## Subclass that only overrides item_from_line
class HoldingLoaderTsv < HoldingLoader
  def item_from_line(line)
    Holding.new_from_holding_file_line(line).tap do |h|
      @organization ||= h.organization
      @current_date ||= h.date_received
    end
  end
end

## Subclass that only overrides item_from_line
class HoldingLoaderNdj < HoldingLoader
  def item_from_line(line)
    Holding.new_from_scrubbed_file_line(line).tap do |h|
      @organization ||= h.organization
      @current_date ||= h.date_received
    end
  end
end
