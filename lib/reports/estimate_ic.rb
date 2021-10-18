# frozen_string_literal: true

require "overlap/ht_item_overlap"
require "utils/waypoint"
require "services"
require "reports/cost_report"

module Reports

  # Generate IC estimate from a list of OCNS
  class EstimateIC
    attr_accessor :ocns, :h_share_total, :num_ocns_matched, :num_items_matched, :num_items_pd,
                  :num_items_ic, :clusters_seen, :waypoint

    def initialize(ocns, batch_size = 100_000)
      @ocns = ocns.uniq
      @h_share_total = 0
      @num_ocns_matched = 0
      @num_items_matched = 0
      @num_items_pd = 0
      @num_items_ic = 0
      @clusters_seen = Set.new
      @waypoint = Utils::Waypoint.new(batch_size)
    end

    def cost_report
      @cost_report ||= CostReport.new
    end

    def run
      ocns.each do |ocn|
        waypoint.incr
        cluster = Cluster.find_by(ocns: ocn.to_i,
                                  "ht_items.0": { "$exists": 1 })
        next if cluster.nil?

        @num_ocns_matched += 1

        next if clusters_seen.include?(cluster._id)

        count_matching_items(cluster)

        waypoint.on_batch {|wp| Services.logger.info wp.batch_line }
      end
      Services.logger.info waypoint.final_line
    end

    def pct_ocns_matched
      @num_ocns_matched.to_f / @ocns.uniq.count * 100
    end

    def pct_items_pd
      @num_items_pd / @num_items_matched.to_f * 100
    end

    def pct_items_ic
      @num_items_ic / @num_items_matched.to_f * 100
    end

    def total_estimated_ic_cost
      @h_share_total * cost_report.cost_per_volume
    end

    private

    def count_matching_items(cluster)
      @clusters_seen << cluster._id

      @num_items_matched += cluster.ht_items.count
      cluster.ht_items.each do |ht_item|
        if ht_item.access == "allow"
          @num_items_pd += 1
          next
        end
        @num_items_ic += 1

        overlap = Overlap::HtItemOverlap.new(ht_item)
        # Insert a placeholder for the prospective member
        overlap.matching_members << "prospective_member"
        @h_share_total += overlap.h_share("prospective_member")
      end
    end

  end
end
