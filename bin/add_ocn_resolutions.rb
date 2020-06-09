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

Zinzout.zin(ARGV.shift).each_with_index do |line, count|
  (deprecated, resolved) = line.split.map(&:to_i)
  r = OCNResolution.new(deprecated: deprecated, resolved: resolved)
  c = ClusterOCNResolution.new(r).cluster
  c.save

  if (count % BATCH_SIZE).zero? && !count.zero?
    waypoint.mark(count)
    # rubocop:disable Layout/LineLength
    logger.info "#{ppnum(count, 10)}. This batch #{ppnum(waypoint.batch_records, 5)} in #{ppnum(waypoint.batch_seconds, 4, 1)}s (#{waypoint.batch_rate_str} r/s). Overall #{waypoint.total_rate_str} r/s."
    # rubocop:enable Layout/LineLength
  end
end
