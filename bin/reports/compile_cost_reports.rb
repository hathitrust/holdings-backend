#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"
require "utils/ppnum"
require "reports/cost_report"

Services.mongo!

def to_tsv(report)
  tsv = []
  tsv << ["member_id", "spm", "mpm", "ser", "pd", "weight", "extra", "total"].join("\t")
  Services.ht_organizations.members.keys.sort.each do |member|
    next unless report.organization.nil? || (member == report.organization.to_s)

    tsv << [
      member,
      report.spm_costs(member),
      report.mpm_costs(member),
      report.ser_costs(member),
      report.pd_cost_for_member(member),
      Services.ht_organizations[member].weight,
      report.extra_per_member,
      report.total_cost_for_member(member)
    ].join("\t")
  end
  tsv.join("\n")
end

def main
  batch_size = 1_000
  marker = Services.progress_tracker.new(batch_size)
  logger = Services.logger
  logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum batch_size}"

  org = ARGV.shift

  cost_report = Reports::CostReport.new(org, lines: batch_size, logger: logger)
  puts "Target cost: #{cost_report.target_cost}"
  puts "Num volumes: #{cost_report.num_volumes}"
  puts "Num pd volumes: #{cost_report.num_pd_volumes}"
  puts "Cost per volume: #{cost_report.cost_per_volume}"
  puts "Total weight: #{cost_report.total_weight}"
  puts "PD Cost: #{cost_report.pd_cost}"
  puts "Num members: #{Services.ht_organizations.members.count}"

  puts to_tsv(cost_report)
  # Dump freq table to file
  ymd = Time.new.strftime("%F")
  cost_report.dump_freq_table("freq_#{ymd}.txt")
  logger.info marker.final_line
end

main if __FILE__ == $PROGRAM_NAME
