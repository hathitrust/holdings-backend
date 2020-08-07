# frozen_string_literal: true

require "cluster"

# The most basic overlap record
# Inherited by SinglePartOverlap and MultiPartOverlap and used for Serials
class Overlap

  def initialize(cluster, org, ht_item)
    @cluster = cluster
    @org = org
    @ht_item = ht_item
  end

  # These methods should return an empty string in the most basic case
  ["copy", "brt", "wd", "lm", "access"].each do |method|
    define_method "#{method}_count".to_sym do
      ""
    end
  end

  def to_hash
    {
      cluster_id:   @cluster._id.to_s,
      volume_id:    @ht_item.item_id,
      member_id:    @org,
      copy_count:   copy_count,
      brt_count:    brt_count,
      wd_count:     wd_count,
      lm_count:     lm_count,
      access_count: access_count
    }
  end
end
