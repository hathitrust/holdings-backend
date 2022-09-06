#!/usr/bin/env ruby
# frozen_string_literal: true

require "zinzout"
require "services"
require "reports/estimate_ic"

# Given a file of unique OCNs, generate a cost estimate.
class CompileEstimate
  def run(ocn_file, output_filename = report_file(ocn_file))
    batch_size = 100_000

    ocns = File.open(ocn_file).map(&:to_i)
    est = Reports::EstimateIC.new(ocns, batch_size)

    Services.logger.info "Target Cost: #{est.cost_report.target_cost}"
    Services.logger.info "Cost per volume: #{est.cost_report.cost_per_volume}"
    Services.logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum batch_size}"

    est.run

    File.open(output_filename, "w") do |fh|
      fh.puts [
        "Total Estimated IC Cost: $#{est.total_estimated_ic_cost.round(2)}",
        "In all, we received #{est.ocns.count} distinct OCLC numbers.",
        "Of those distinct OCLC numbers, #{est.num_ocns_matched} (#{est.pct_ocns_matched.round(1)}%) match items in",
        "HathiTrust, corresponding to #{est.num_items_matched} HathiTrust items.",
        "Of those items, #{est.num_items_pd} (#{est.pct_items_pd.round(1)}%) are in the public domain,",
        "#{est.num_items_ic} (#{est.pct_items_ic.round(1)}%) are in copyright."
      ].join("\n")
    end
  end

  private

  def report_file(ocn_file)
    FileUtils.mkdir_p(Settings.estimates_path)
    File.join(Settings.estimates_path, File.basename(ocn_file, ".txt") + "-estimate-#{Date.today}.txt")
  end
end
