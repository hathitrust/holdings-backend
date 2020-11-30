# frozen_string_literal: true

require "overlap"

# Overlap record for items in MPM clusters
class MultiPartOverlap < Overlap

  def members_with_matching_ht_items
    if @ht_item.n_enum == ""
      @cluster.billing_entities
    else
      (@cluster.item_enum_chron_orgs[@ht_item.n_enum] + @cluster.item_enum_chron_orgs[""]).uniq
    end
  end

  def copy_count
    cc = matching_holdings.count
    if cc.zero? && (members_with_matching_ht_items.include? @org)
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
    if @ht_item.n_enum == ""
      @cluster.holdings.where(organization: @org)
    else
      @cluster.holdings.where(organization: @org,
                              "$or": [{ n_enum: @ht_item.n_enum }, { n_enum: "" }])
    end
  end

end
