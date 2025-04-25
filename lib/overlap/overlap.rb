# frozen_string_literal: true

module Overlap
  # The most basic overlap record
  # Inherited by SinglePartOverlap, MultiPartOverlap, and SerialOverlap
  class Overlap
    attr_accessor :org, :ht_item, :cluster

    def initialize(org, ht_item)
      @cluster = ht_item.cluster
      @org = org
      @ht_item = ht_item
    end

    # These methods should return zero in the most basic case
    ["copy", "brt", "wd", "lm", "access"].each do |method|
      define_method :"#{method}_count" do
        0
      end
    end

    def matching_holdings
      @cluster.holdings_by_org[@org] || []
    end

    def to_hash
      {
        volume_id: @ht_item.item_id,
        n_enum: @ht_item.n_enum,
        member_id: @org,
        copy_count: copy_count,
        brt_count: brt_count,
        wd_count: wd_count,
        lm_count: lm_count,
        access_count: access_count
      }
    end
  end
end
