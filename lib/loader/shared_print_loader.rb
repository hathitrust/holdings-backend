# frozen_string_literal: true

require "clusterable/commitment"
require "clustering/cluster_commitment"
require "utils/tsv_reader"

module Loader
  # Constructs batches of Commitments from incoming file data
  class SharedPrintLoader
    def self.for(filename)
      if filename.end_with?(".tsv")
        SharedPrintLoaderTSV.new
      elsif filename.end_with?(".ndj")
        SharedPrintLoaderNDJ.new
      else
        raise "given an invalid file extension"
      end
    end

    def self.filehandle_for(filename)
      if filename.end_with?(".tsv")
        Utils::TSVReader.new(filename)
      elsif filename.end_with?(".ndj")
        File.open(filename, "r")
      else
        raise "given an invalid file extension"
      end
    end

    def load(batch)
      Clustering::ClusterCommitment.new(batch).cluster
    end

    def normalize_fields(fields)
    end
  end

  #
  ## Subclass that only overrides item_from_line
  class SharedPrintLoaderTSV < SharedPrintLoader
    def item_from_line(line)
      # Utils::TSVReader takes care of parsing into fields, but we still need
      # to clean them up
      fields = line.compact.reject { |k, v| v.empty? }
      fields[:policies] = fields.fetch(:policies, "").downcase.split(",")

      Clusterable::Commitment.new(fields)
    end
  end

  ## Subclass that only overrides item_from_line
  class SharedPrintLoaderNDJ < SharedPrintLoader
    def item_from_line(json)
      fields = JSON.parse(json).compact.symbolize_keys
      fields[:policies] = fields.fetch(:policies, []).map(&:downcase)

      Clusterable::Commitment.new(fields)
    end
  end
end
