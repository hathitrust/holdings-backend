# frozen_string_literal: true

require "cluster"
require "overlap"

# Overlap record for items in Serial clusters
class SerialOverlap < Overlap

  def copy_count
    cc = @cluster.holdings.where(organization: @org).count
    if !cc.zero? || @ht_item.billing_entity == @org
      1
    else
      0
    end
  end

end
