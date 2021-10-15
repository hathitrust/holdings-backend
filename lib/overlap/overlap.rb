# frozen_string_literal: true

require "cluster"

# The most basic overlap record
# Inherited by SinglePartOverlap, MultiPartOverlap, and SerialOverlap
class Overlap
  attr_accessor :org, :ht_item, :cluster

  def initialize(cluster, org, ht_item)
    @cluster = cluster
    @org = org
    @ht_item = ht_item
  end

  # These methods should return zero in the most basic case
  ["copy", "brt", "wd", "lm", "access"].each do |method|
    define_method "#{method}_count".to_sym do
      0
    end
  end

  def matching_holdings
    @cluster.holdings_by_org[@org] || []
  end

  def to_hash
    {
      lock_id:      lock_id,
      cluster_id:   @cluster._id.to_s,
      volume_id:    @ht_item.item_id,
      n_enum:       @ht_item.n_enum,
      member_id:    @org,
      copy_count:   copy_count,
      brt_count:    brt_count,
      wd_count:     wd_count,
      lm_count:     lm_count,
      access_count: access_count
    }
  end

  # Precomputed for the ETAS tables
  def lock_id
    case @cluster.format
    when "mpm"
      [@cluster._id.to_s, @ht_item.n_enum].join(":")
    when "spm"
      @cluster._id.to_s
    when "ser", "ser/spm"
      @ht_item.item_id
    end
  end
end
