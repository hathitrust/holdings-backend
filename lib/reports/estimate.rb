# frozen_string_literal: true

require "overlap/ht_item_overlap"
require "services"
require "reports/cost_report"

module Reports
  # Generate IC estimate from a list of OCNS
  class Estimate
    attr_accessor :ocns, :ocn_file, :h_share_total, :num_ocns_matched, :num_items_matched, :num_items_pd,
      :num_items_ic, :clusters_seen, :marker

    def initialize(ocn_file = nil, batch_size = 100_000)
      @ocn_file = ocn_file
      @h_share_total = 0
      @num_ocns_matched = 0
      @num_items_matched = 0
      @num_items_pd = 0
      @num_items_ic = 0
      @clusters_seen = Set.new
      @marker = Services.progress_tracker.new(batch_size)
    end

    def cost_report
      @cost_report ||= CostReport.new
    end

    def find_matching_ocns(ocns = @ocns)
      ocns.each do |ocn|
        marker.incr
        cluster = Cluster.find_by(ocns: ocn.to_i,
          "ht_items.0": {"$exists": 1})
        next if cluster.nil?

        @num_ocns_matched += 1

        next if clusters_seen.include?(cluster._id)

        count_matching_items(cluster)

        marker.on_batch { |m| Services.logger.info m.batch_line }
      end
      Services.logger.info marker.final_line
    end

    def run(output_filename = report_file(ocn_file))
      @ocns = File.open(ocn_file).map(&:to_i).uniq

      Services.logger.info "Target Cost: #{cost_report.target_cost}"
      Services.logger.info "Cost per volume: #{cost_report.cost_per_volume}"
      Services.logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum marker.batch_size}"

      find_matching_ocns(ocns)

      File.open(output_filename, "w") do |fh|
        fh.puts [
          "Total Estimated IC Cost: $#{total_estimated_ic_cost.round(2)}",
          "In all, we received #{ocns.count} distinct OCLC numbers.",
          "Of those distinct OCLC numbers, #{num_ocns_matched} (#{pct_ocns_matched.round(1)}%) match items in",
          "HathiTrust, corresponding to #{num_items_matched} HathiTrust items.",
          "Of those items, #{num_items_pd} (#{pct_items_pd.round(1)}%) are in the public domain,",
          "#{num_items_ic} (#{pct_items_ic.round(1)}%) are in copyright."
        ].join("\n")
      end
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

    def report_file(ocn_file)
      FileUtils.mkdir_p(Settings.estimates_path)
      File.join(Settings.estimates_path, File.basename(ocn_file, ".txt") + "-estimate-#{Date.today}.txt")
    end
  end
end
