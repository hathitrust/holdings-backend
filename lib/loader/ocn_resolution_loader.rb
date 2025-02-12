# frozen_string_literal: true

require "clusterable/ocn_resolution"
require "clustering/cluster_ocn_resolution"

module Loader
  # Constructs batches of HtItems from incoming file data
  class OCNResolutionLoader
    def item_from_line(line)
      (variant, canonical) = line.split.map(&:to_i)
      Clusterable::OCNResolution.new(variant: variant, canonical: canonical)
    end

    def load(batch)
      Clustering::ClusterOCNResolution.new(batch).cluster
    end

    def delete(item)
      Clustering::ClusterOCNResolution.new(item).delete
    end

    def batches_for(enumerable)
      enumerable.chunk_while { |item1, item2| item1.batch_with?(item2) }
    end
  end
end
