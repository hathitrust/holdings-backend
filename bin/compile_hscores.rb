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

Mongoid.load!("mongoid.yml", :development)

if __FILE__ == $PROGRAM_NAME
  BATCH_SIZE = 10_000
  waypoint = Utils::Waypoint.new(BATCH_SIZE)
  logger = Logger.new(STDERR)
  logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

  org = ARGV.shift

  cost_report = CostReport.new(org)
  cost_report.matching_clusters.each do |c|
    c.ht_items.each do |ht_item|
      next unless ht_item.access == "deny"

      waypoint.incr
      cost_report.add_ht_item_to_freq_table(ht_item)
      waypoint.on_batch {|wp| logger.info wp.batch_line }
    end
  end
  puts cost_report.freq_table.to_json
  logger.info waypoint.final_line
  if org.nil?
    puts cost_report.total_hscore.to_json
  else
    puts cost_report.total_hscore[org.to_sym].to_json
  end
end
