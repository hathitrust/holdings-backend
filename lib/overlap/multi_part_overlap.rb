require "overlap/overlap"

module Overlap
  # Overlap record for items in MPM clusters
  class MultiPartOverlap < Overlap
    def current_holding_count
      # holding is assumed current if status is nil
      matching_holdings.count { |h| h.status == "CH" || h.status.nil? }
    end

    def brt_count
      matching_holdings.count { |h| h.condition == "BRT" }
    end

    def wd_count
      matching_holdings.count { |h| h.status == "WD" }
    end

    def lm_count
      matching_holdings.count { |h| h.status == "LM" }
    end

    # Number of holdings with brt or lm
    def access_count
      matching_holdings.count { |h| h.status == "LM" or h.condition == "BRT" }
    end

    def matching_holdings
      @matching_holdings ||= @cluster.holdings_by_org[@org]
        &.select do |h|
          matching_enum?(h) || empty_enum?(h) || no_matches_for_holding_org?(h)
        end
      @matching_holdings ||= []
    end

    def matching_count
      matching_holdings.count
    end

    private

    def matching_enum?(holding)
      holding.n_enum == @ht_item.n_enum
    end

    def empty_enum?(holding)
      holding.n_enum.nil? || holding.n_enum == ""
    end

    def no_matches_for_holding_org?(holding)
      @cluster.organizations_with_holdings_but_no_matches.include?(holding.organization)
    end
  end
end
