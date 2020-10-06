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

if __FILE__ == $PROGRAM_NAME
  BATCH_SIZE = 10_000
  waypoint = Utils::Waypoint.new(BATCH_SIZE)
  logger = Services.logger
  logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

  org = ARGV.shift

  cost_report = CostReport.new(org, maxlines: BATCH_SIZE, logger: logger)

  logger.info waypoint.final_line
  puts cost_report.to_tsv
end
