# frozen_string_literal: true

require "overlap/cluster_overlap"
require "clusterable/ht_item"

module Overlap
  # Collects organizations with an HTItem overlap
  class HtItemOverlap
    attr_reader :ht_item, :matching_orgs, :matching_members

    def initialize(ht_item)
      @ht_item = ht_item

      overlap = ClusterOverlap.new(ht_item.cluster).for_item(ht_item)
      # Find all organization with holdings that match the given ht_item
      @matching_orgs = overlap.map(&:org)
      # Find all *members* with holdings that match the given ht_item
      @matching_members = (matching_orgs & Services.ht_organizations.members.keys)
    end

    # Share of this particular item and organization
    # Used only for estimate creation
    def h_share(organization)
      if matching_members.include? organization
        1.0 / matching_members.count
      else
        0.0
      end
    end
  end
end
