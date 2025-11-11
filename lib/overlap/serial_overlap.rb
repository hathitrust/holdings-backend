# frozen_string_literal: true

require "cluster"
require "overlap/overlap"

module Overlap
  # Overlap record for items in Serial clusters
  class SerialOverlap < Overlap
    def matching_count
      @cluster.copy_counts[@org].clamp(0..1)
    end

    # serials don't have withdrawn/lost/missing/etc
    def current_holding_count
      matching_count
    end
  end
end
