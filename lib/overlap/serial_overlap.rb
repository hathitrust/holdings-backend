# frozen_string_literal: true

require "cluster"
require "overlap/overlap"

module Overlap
  # Overlap record for items in Serial clusters
  class SerialOverlap < Overlap::Overlap
    def copy_count
      cc = @cluster.copy_counts[@org]
      if !cc.zero? || @ht_item.billing_entity == @org
        1
      else
        0
      end
    end
  end
end
