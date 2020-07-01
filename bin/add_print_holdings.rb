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

update = ARGV[0] == "-u"
if update
  filename = ARGV[1]
  logger.info "Updating Print Holdings."
else
  filename = ARGV[0]
  logger.info "Adding Print Holdings."
end

organization = nil
current_date = nil
Zinzout.zin(filename).each do |line|
  next if /^OCN\tBIB/.match?(line)

  waypoint.incr
  h = Holding.new_from_holding_file_line(line)
  organization = (organization || h.organization)
  current_date = (current_date || h.date_received)
  c = if update
    ClusterHolding.new(h).update
  else
    ClusterHolding.new(h).cluster
  end
  c.save!
  waypoint.on_batch {|wp| logger.info wp.batch_line }
end

if update
  ClusterHolding.delete_old_holdings(organization, current_date)
end

logger.info waypoint.final_line
