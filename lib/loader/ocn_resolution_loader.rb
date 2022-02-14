# frozen_string_literal: true

require "clusterable/ocn_resolution"
require "clustering/cluster_ocn_resolution"

module Loader
  # Constructs batches of HtItems from incoming file data
  class OCNResolutionLoader
    def item_from_line(line)
      (deprecated, resolved) = line.split.map(&:to_i)
      Clusterable::OCNResolution.new(deprecated: deprecated, resolved: resolved)
    end

    def load(batch)
      Clustering::ClusterOCNResolution.new(batch).cluster
    end

    def delete(item)
      Clustering::ClusterOCNResolution.new(item).delete
    end
  end
end
