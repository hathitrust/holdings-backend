#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "utils/waypoint"
require "utils/ppnum"
require "zinzout"
require "ht_item_overlap"

Mongoid.load!("mongoid.yml", ENV["MONGOID_ENV"] || :development)

if __FILE__ == $PROGRAM_NAME
  BATCH_SIZE = 10_000
  waypoint = Utils::Waypoint.new(BATCH_SIZE)
  logger = Logger.new(STDERR)
  logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

  ocn_file = ARGV.shift
  h_share_total = 0.0
  ht_items_seen = []

  File.open(ocn_file).each do |line|
    ocn = line.to_i
    waypoint.incr

    # Find a cluster
    cluster = Cluster.find_by(ocns: ocn.to_i,
                            "ht_items.0": { "$exists": 1 })
    next if cluster.nil?

    cluster.ht_items.each do |ht_item|
      next unless ht_item.access == "deny"

      # Multiple OCLCs can map to the same cluster, but we only want them once
      next if ht_items_seen.include? ht_item.item_id

      ht_items_seen << ht_item.item_id

      overlap = HtItemOverlap.new(ht_item)
      # Insert a placeholder for the prospective member
      overlap.matching_orgs << "prospective_member"
      h_share_total += overlap.h_share("prospective_member")
    end
    waypoint.on_batch {|wp| logger.info wp.batch_line }
  end
  logger.info waypoint.final_line

  puts "Total HScore:#{h_share_total}"
end
