#!/usr/bin/env ruby
# frozen_string_literal: true

require "zinzout"
require "services"
require "reports/estimate_ic"

Services.mongo!

# Given a file of unique OCNs, generate a cost estimate.

def main
  batch_size = 100_000

  ocn_file = ARGV.shift
  ocns = File.open(ocn_file).map(&:to_i)
  est = Reports::EstimateIC.new(ocns, batch_size)

  Services.logger.info "Target Cost: #{est.cost_report.target_cost}"
  Services.logger.info "Cost per volume: #{est.cost_report.cost_per_volume}"
  Services.logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum batch_size}"

  est.run

  puts "Total Estimated IC Cost:#{est.total_estimated_ic_cost}
In all, we received #{est.ocns.count} distinct OCLC numbers.
Of those distinct OCLC numbers, #{est.num_ocns_matched} (#{est.pct_ocns_matched.round(1)}%) match in
HathiTrust, corresponding to #{est.num_items_matched} HathiTrust items.
Of those, #{est.num_items_pd} ( #{est.pct_items_pd.round(1)}%) are in the public domain,
#{est.num_items_ic} ( #{est.pct_items_ic} ) are in copyright."
end

main if $PROGRAM_NAME == __FILE__
