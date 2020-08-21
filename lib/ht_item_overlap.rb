# frozen_string_literal: true

require "cluster_overlap"
require "ht_item"

# Collects
class HtItemOverlap

  attr_accessor :matching_orgs

  def initialize(ht_item)
    @ht_item = ht_item
    @cluster = ht_item._parent
    @matching_orgs = organizations_with_holdings
  end

  # Find all organization with holdings that match the given ht_item
  def organizations_with_holdings
    co = ClusterOverlap.new(@cluster)
    co.orgs.map {|cluster_org| co.overlap_record(@ht_item, cluster_org) }
      .select {|overlap| overlap.copy_count.nonzero? }
      .collect(&:org)
      .uniq
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
