#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "cluster_ocn_resolution"
require "ocn_resolution"
require "zinzout"
require "logger"
require "utils/waypoint"
require "utils/ppnum"

Mongoid.load!("mongoid.yml", :test)

BATCH_SIZE = 10_000
logger = Logger.new(STDOUT)
waypoint = Utils::Waypoint.new

# rubocop:disable Layout/LineLength
logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"
# rubocop:enable Layout/LineLength

count = 0
Zinzout.zin(ARGV.shift).each do |line|
  count += 1
  (deprecated, resolved) = line.split.map(&:to_i)
  r = OCNResolution.new(deprecated: deprecated, resolved: resolved)
  c = ClusterOCNResolution.new(r).cluster
  c.save

  if (count % BATCH_SIZE).zero? && !count.zero?
    waypoint.mark(count)
    logger.info waypoint.batch_line
  end
end

waypoint.mark(count)
logger.info waypoint.final_line

