# frozen_string_literal: true

require "cluster"

module Clustering
  # Cluster getter for OCN-less HTItems
  #
  # Returns the cluster containing the HTItem or a new cluster if one does not
  # exist.
  class HtItemClusterGetter
    def initialize(ht_item)
      @ht_item = ht_item

      raise ArgumentError, "only for ocnless HTItems" unless @ht_item.ocns.empty?
    end

    def get
      raise "not implemented"
      Retryable.new.run do
        try_strategies.tap { |c| yield c if block_given? }
      end
    end

    private

    def try_strategies
      Cluster.with_ht_item(@ht_item).first || Cluster.create(ocns: [])
    end
  end
end
