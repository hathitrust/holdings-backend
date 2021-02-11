# frozen_string_literal: true

require "overlap"

# Overlap record for items in MPM clusters
class MultiPartOverlap < Overlap

  def copy_count
    cc = matching_holdings.count
    if cc.zero? && @ht_item.billing_entity == @org
      1
    else
      cc
    end
  end

  def brt_count
    matching_holdings.where(condition: "BRT").count
  end

  def wd_count
    matching_holdings.where(status: "WD").count
  end

  def lm_count
    matching_holdings.where(status: "LM").count
  end

  # Number of holdings with brt or lm
  def access_count
    matching_holdings.where("$or": [{ status: "LM" }, { condition: "BRT" }]).count
  end

  def matching_holdings
    @cluster.holdings.where(organization: @org,
                            "$or": [{ n_enum_chron: @ht_item.n_enum_chron }, { n_enum_chron: "" }])
  end

end
