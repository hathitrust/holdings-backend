# frozen_string_literal: true

require "clustering/cluster_holding"

module Loader
  # Constructs batches of Holdings from incoming file data
  class HoldingLoader
    def self.for(filename)
      if filename.end_with?(".tsv")
        HoldingLoaderTSV.new
      elsif filename.end_with?(".ndj")
        HoldingLoaderNDJ.new
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
      Clustering::ClusterHolding.new(batch).cluster
    end

    def final_line
      if @update
        Clustering::ClusterHolding.delete_old_holdings(@organization, @current_date)
      end
    end
  end

  ## Subclass that only overrides item_from_line
  class HoldingLoaderTSV < HoldingLoader
    def item_from_line(line)
      Clusterable::Holding.new_from_holding_file_line(line).tap do |h|
        @organization ||= h.organization
        @current_date ||= h.date_received
      end
    end
  end

  ## Subclass that only overrides item_from_line
  class HoldingLoaderNDJ < HoldingLoader
    def item_from_line(line)
      Clusterable::Holding.new_from_scrubbed_file_line(line).tap do |h|
        @organization ||= h.organization
        @current_date ||= h.date_received
      end
    end
  end
end
