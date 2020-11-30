# frozen_string_literal: true

require "cluster_overlap"
require "ht_item"

# Collects organizations with an HTItem overlap
class HtItemOverlap

  attr_accessor :matching_orgs

  def initialize(ht_item)
    @ht_item = ht_item
    @cluster = ht_item._parent
    @matching_orgs = organizations_with_holdings
  end

  # Find all organization with holdings that match the given ht_item
  def organizations_with_holdings
    if @cluster.format != "mpm"
      # all orgs in the cluster hold every spm or ser in cluster
      @cluster.organizations_in_cluster
    elsif @ht_item.n_enum == ""
      # all orgs in the cluster match an ht_item without an enum
      @cluster.organizations_in_cluster
    else
      # ht_items match on enum and holdings without enum
      (@cluster.enum_chron_orgs("") + @cluster.enum_chron_orgs(@ht_item.n_enum)).uniq
    end
  end

  # Share of this particular item and organization
  def h_share(organization)
    if @matching_orgs.include? organization
      1.0 / @matching_orgs.count
    else
      0.0
    end
  end
end
