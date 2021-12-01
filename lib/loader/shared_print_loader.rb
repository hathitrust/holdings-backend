# frozen_string_literal: true

require "clusterable/commitment"
require "clustering/cluster_commitment"

module Loader

  # Constructs batches of Commitments from incoming file data
  class SharedPrintLoader
    def item_from_line(json)
      fields = JSON.parse(json).compact

      Clusterable::Commitment.new(fields)
    end

    def load(batch)
      Clustering::ClusterCommitment.new(batch).cluster
    end
  end
end
