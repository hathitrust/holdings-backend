# frozen_string_literal: true

require "overlap/overlap"

module Overlap
  # Overlap record for items in MPM clusters
  class MultiPartOverlap < Overlap

    def copy_count
      cc = matching_holdings.count
      if cc.zero? &&
          (@ht_item.billing_entity == @org ||
           @cluster.organizations_with_holdings_but_no_matches.include?(@org))
        1
      else
        cc
      end
    end

    def brt_count
      matching_holdings.count {|h| h[:condition] == "BRT" }
    end

    def wd_count
      matching_holdings.count {|h| h[:status] == "WD" }
    end

    def lm_count
      matching_holdings.count {|h| h[:status] == "LM" }
    end

    # Number of holdings with brt or lm
    def access_count
      matching_holdings.count {|h| h[:status] == "LM" or h[:condition] == "BRT" }
    end

    def matching_holdings
      @matching_holdings ||= @cluster.holdings_by_org[@org]
                               &.select {|h| h[:n_enum] == @ht_item.n_enum or h[:n_enum] == "" }
      @matching_holdings ||= []
    end

  end
end
