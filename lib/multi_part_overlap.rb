# frozen_string_literal: true

require "overlap"

# Overlap record for items in MPM clusters
class MultiPartOverlap < Overlap

  def copy_count
    cc = matching_holdings.count
    if cc.zero? && (@ht_item.content_provider_code == @org)
      1
    else
      cc
    end
  end

  def brt_count
    matching_holdings.where(condition: "brt").count
  end

  def wd_count
    matching_holdings.where(status: "wd").count
  end

  def lm_count
    matching_holdings.where(status: "lm").count
  end

  # Number of holdings with brt or lm
  def access_count
    matching_holdings.where("$or": [{ status: "lm" }, { condition: "brt" }]).count
  end

  def matching_holdings
    if @ht_item.n_enum.nil? || (@ht_item.n_enum == "")
      @cluster.holdings.where(organization: @org)
    else
      @cluster.holdings.where(organization: @org,
                              "$or": [{ n_enum: @ht_item.n_enum }, { n_enum: "" }])
    end
  end

end