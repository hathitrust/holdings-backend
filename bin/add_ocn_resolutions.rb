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
waypoint = Utils::Waypoint.new(BATCH_SIZE)

# rubocop:disable Layout/LineLength
logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"
# rubocop:enable Layout/LineLength

STDIN.set_encoding 'utf-8'
Zinzout.zin(ARGV.shift).each do |line|
  waypoint.incr
  (deprecated, resolved) = line.split.map(&:to_i)
  r = OCNResolution.new(deprecated: deprecated, resolved: resolved)
  c = ClusterOCNResolution.new(r).cluster
  c.save
  waypoint.on_batch {|wp| logger.info wp.batch_line}
end

logger.info waypoint.final_line

