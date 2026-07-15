require "clusterable/ht_item"
require "overlap/cluster_overlap"

module Overlap
  class ItemNonCurrentHoldings
    attr_reader :ht_item

    def self.from_json(json)
      json = JSON.parse(json) if json.is_a?(String)

      ht_item = Clusterable::HtItem.new
      ht_item.item_id = json["item_id"]
      ht_item.rights = json["rights"]

      non_current_holdings = json["non_current_holdings"].transform_values(&:to_sym)

      new(ht_item, non_current_holdings)
    end

    def initialize(ht_item, non_current_holdings = nil)
      @ht_item = ht_item
      @non_current_holdings ||= non_current_holdings
    end

    def to_h
      {
        item_id: ht_item.item_id,
        rights: ht_item.rights,
        non_current_holdings: non_current_holdings
      }
    end

    def non_current_holdings
      @non_current_holdings ||= build_non_current_holdings.to_h
    end

    private

    def analyze_overlap_records(overlap_records)
      conditions = Set.new

      # i.e. make sure there are no current, non-brittle holdings
      return unless overlap_records.all?(&:all_current_holdings_brittle?)

      # there is at least one current holding that is brittle
      conditions.add(:brittle) if overlap_records.any?(&:any_current_holdings_brittle?)

      conditions.add(:lost_missing) if overlap_records.sum(&:lm_count).positive?
      conditions.add(:withdrawn) if overlap_records.sum(&:wd_count).positive?

      single_condition(conditions)
    end

    def single_condition(conditions)
      case conditions.size
      when 0
        nil
      when 1
        conditions.first
      else
        :multiple
      end
    end

    def build_non_current_holdings
      return enum_for(__method__) unless block_given?

      overlaps = ClusterOverlap.new(ht_item.cluster).for_item(ht_item).to_a

      overlaps_by_org = overlaps.group_by(&:org)

      overlaps_by_org.each do |org, overlaps|
        condition = analyze_overlap_records(overlaps)
        yield [org, condition] if condition
      end
    end
  end
end
