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

Mongoid.load!("mongoid.yml", ENV["MONGOID_ENV"] || :development)

BATCH_SIZE = 10_000
logger = Services.logger
waypoint = Utils::Waypoint.new(BATCH_SIZE)
logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

STDIN.set_encoding "utf-8"
Zinzout.zin(ARGV.shift).each do |line|
  begin
    waypoint.incr
    (deprecated, resolved) = line.split.map(&:to_i)
    r = OCNResolution.new(deprecated: deprecated, resolved: resolved)
    c = ClusterOCNResolution.new(r).cluster
    c.save if c.changed?
    waypoint.on_batch {|wp| logger.info wp.batch_line }
  rescue StandardError => e
    logger.error "Encountered error while processing line: "
    logger.error line
    logger.error e.message
    logger.error e.backtrace.inspect
    raise e
  end
end

logger.info waypoint.final_line
