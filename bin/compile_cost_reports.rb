#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "utils/waypoint"
require "utils/ppnum"
require "cost_report"
require "ht_item_overlap"

Mongoid.load!("mongoid.yml", ENV["MONGOID_ENV"])

def to_tsv(report)
  tsv = []
  tsv << ["member_id", "spm", "mpm", "ser", "pd", "weight", "extra", "total"].join("\t")
  Services.ht_members.members.keys.sort.each do |member|
    next unless report.organization.nil? || (member == report.organization.to_s)

    tsv << [
      member,
      report.spm_costs(member),
      report.mpm_costs(member),
      report.ser_costs(member),
      report.pd_cost_for_member(member),
      Services.ht_members[member].weight,
      report.extra_per_member,
      report.total_cost_for_member(member)
    ].join("\t")
  end
  tsv.join("\n")
end

if __FILE__ == $PROGRAM_NAME
  BATCH_SIZE = 1_000
  waypoint = Utils::Waypoint.new(BATCH_SIZE)
  logger = Services.logger
  logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

  org = ARGV.shift

  cost_report = CostReport.new(org, lines: BATCH_SIZE, logger: logger)

  puts to_tsv(cost_report)
  logger.info waypoint.final_line
end
