#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "cluster_holding"
require "ocn_resolution"
require "holding"
require "utils/waypoint"
require "utils/ppnum"
require "zinzout"

Mongoid.load!("mongoid.yml", :test)

BATCH_SIZE = 10_000
waypoint = Utils::Waypoint.new(BATCH_SIZE)
logger = Logger.new(STDOUT)

# rubocop:disable Layout/LineLength
logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"
# rubocop:enable Layout/LineLength

count = 0
Zinzout.zin(ARGV.shift).each do |line|
  next if /^OCN\tBIB/.match?(line)
  waypoint.incr
  h = Holding.new_from_holding_file_line(line)
  c = ClusterHolding.new(h).cluster
  c.save
  waypoint.on_batch {|wp| logger.info wp.batch_line}
end

logger.info waypoint.final_line
