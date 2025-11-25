# frozen_string_literal: true

require "overlap/cluster_overlap"
require "clusterable/ht_item"

module Overlap
  # Collects organizations with an HTItem overlap
  class HtItemOverlap
    attr_accessor :matching_orgs, :matching_members, :ht_item

    def initialize(ht_item)
      @ht_item = ht_item
      @cluster = ht_item.cluster
      @matching_orgs = organizations_with_holdings
      @matching_members = members_with_holdings
    end

    # Find all organization with holdings that match the given ht_item
    def organizations_with_holdings
      ClusterOverlap.new(@cluster).for_item(@ht_item).map(&:org)
    end

    # Find all *members* with holdings that match the given ht_item
    def members_with_holdings
      @matching_orgs & Services.ht_organizations.members.keys
    end

    # Share of this particular item and organization
    # Used only for estimate creation
    def h_share(organization)
      if @matching_members.include? organization
        1.0 / @matching_members.count
      else
        0.0
      end
    end
  end
end
