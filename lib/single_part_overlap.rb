# frozen_string_literal: true

require "overlap"

# Overlap record for items in SPM clusters
class SinglePartOverlap < Overlap

  def copy_count
    cc = @cluster.holdings.where(organization: @org).count
    if cc.zero? && (members_with_matching_ht_items.include? @org)
      1
    else
      cc
    end
  end

  def brt_count
    @cluster.holdings.where(organization: @org, condition: "BRT").count
  end

  def wd_count
    @cluster.holdings.where(organization: @org, status: "WD").count
  end

  def lm_count
    @cluster.holdings.where(organization: @org, status: "LM").count
  end

  # Number of holdings with brt or lm
  def access_count
    @cluster.holdings.where(
      organization: @org, "$or": [{ status: "LM" }, { condition: "BRT" }]
    ).count
  end

end
