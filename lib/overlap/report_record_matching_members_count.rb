# frozen_string_literal: true

require "overlap/report_record"

module Overlap
  class ReportRecord::MatchingMembersCount < ReportRecord
    attr_reader :matching_members_count

    def initialize(holding: nil, ht_item: nil)
      super
      @matching_members_count = HtItemOverlap.new(ht_item).matching_members.count
    end

    def fields
      super + [matching_members_count]
    end

    def self.header_fields
      super + ["matching_members_count"]
    end
  end
end
