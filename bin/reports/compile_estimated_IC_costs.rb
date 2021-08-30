#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "utils/waypoint"
require "utils/ppnum"
require "zinzout"
require "ht_item_overlap"
require "report/cost_report"
require "services"

Services.mongo!

# Given a file of unique OCNs, generate a cost estimate.

if __FILE__ == $PROGRAM_NAME
  BATCH_SIZE = 10_000
  waypoint = Utils::Waypoint.new(BATCH_SIZE)
  logger = Logger.new($stderr)
  cost_report = Report::CostReport.new
  logger.info "Target Cost: #{cost_report.target_cost}"
  logger.info "Cost per volume: #{cost_report.cost_per_volume}"
  logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

  ocns = []
  ocn_file = ARGV.shift
  h_share_total = 0.0
  clusters_seen = Set.new
  num_ocns_matched = 0
  num_items_matched = 0
  num_items_pd = 0
  num_items_ic = 0

  File.open(ocn_file).each do |line|
    ocn = line.to_i
    ocns << ocn
    waypoint.incr

    # Find a cluster
    cluster = Cluster.find_by(ocns: ocn.to_i,
                            "ht_items.0": { "$exists": 1 })
    next if cluster.nil?

    num_ocns_matched += 1

    # Multiple OCLCs can map to the same cluster, but we only want them once
    next if clusters_seen.include?(cluster._id)

    clusters_seen << cluster._id

    num_items_matched += cluster.ht_items.count

    cluster.ht_items.each do |ht_item|
      if ht_item.access == "allow"
        num_items_pd += 1
        next
      end
      # next unless ht_item.access == "deny"
      num_items_ic += 1

      overlap = HtItemOverlap.new(ht_item)
      # Insert a placeholder for the prospective member
      overlap.matching_orgs << "prospective_member"
      h_share_total += overlap.h_share("prospective_member")
    end
    waypoint.on_batch {|wp| logger.info wp.batch_line }
  end
  logger.info waypoint.final_line

  pct_ocns_matched = num_ocns_matched.to_f / ocns.uniq.count * 100
  pct_items_pd = num_items_pd / num_items_matched.to_f * 100
  pct_items_ic = num_items_ic / num_items_matched.to_f * 100

  puts "Total Estimated IC Cost:#{h_share_total * cost_report.cost_per_volume}
In all, we received #{ocns.uniq.count} distinct OCLC numbers.
Of those distinct OCLC numbers, #{num_ocns_matched} (#{pct_ocns_matched.round(1)}%) match in
HathiTrust, corresponding to #{num_items_matched} HathiTrust items.
Of those, #{num_items_pd} ( #{pct_items_pd.round(1)}%) are in the public domain,
#{num_items_ic} ( #{pct_items_ic} ) are in copyright."

end
