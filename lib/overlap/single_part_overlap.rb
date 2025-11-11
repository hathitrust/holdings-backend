# frozen_string_literal: true

require "overlap/overlap"

module Overlap
  # Overlap record for items in SPM clusters
  class SinglePartOverlap < Overlap
    def current_holding_count
      @cluster.current_holding_counts[@org]
    end

    def brt_count
      @cluster.brt_counts[@org]
    end

    def wd_count
      @cluster.wd_counts[@org]
    end

    def lm_count
      @cluster.lm_counts[@org]
    end

    # Number of holdings with brt or lm
    def access_count
      @cluster.access_counts[@org]
    end

    def matching_count
      @cluster.copy_counts[@org]
    end

  end
end
