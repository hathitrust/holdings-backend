# frozen_string_literal: true

require "cluster"
require "overlap/overlap"

module Overlap
  # Overlap record for items in Serial clusters
  class SerialOverlap < Overlap
    def matching_count
      @cluster.copy_counts[@org].clamp(0..1)
    end
  end
end
