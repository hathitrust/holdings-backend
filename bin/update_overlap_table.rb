#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
$LOAD_PATH.unshift(Pathname.new(__dir__).parent + "lib")

require "bundler/setup"
require "cluster"
require "cluster_overlap"
require "logger"
require "services"
require "utils/waypoint"
require "date"

Services.mongo!

TABLENAME = :holdings_htitem_htmember
def overlap_table
  Services.holdings_db[TABLENAME]
end

def upsert_cluster(cluster, logger, waypoint)
  Services.holdings_db.transaction do
    # Remove overlaps for all of the items in this cluster
    cluster.ht_items.map {|ht_item| overlap_table.filter(volume_id: ht_item.item_id).delete }
    # Add new overlaps back in
    ClusterOverlap.new(cluster, nil).each do |overlap|
      waypoint.incr
      overlap_table.insert(overlap.to_hash)
      waypoint.on_batch {|wp| logger.info wp.batch_line }
    end
  end
end

if __FILE__ == $PROGRAM_NAME

  # Default: Now - 36 hours
  cutoff_date = Date.today - 1.5

  unless ARGV.empty?
    cutoff_date = Date.parse(ARGV.shift)
  end

  puts "Upserting clusters last_modified after #{cutoff_date.strftime("%Y-%m-%d %H:%M:%S")}"

  BATCH_SIZE = 1_000
  waypoint = Utils::Waypoint.new(BATCH_SIZE)

  logger = Services.logger
  Cluster.where("ht_items.0": { "$exists": 1 },
                last_modified: { "$gt": cutoff_date }).no_timeout.each do |cluster|
                  upsert_cluster(cluster, logger, waypoint)
                end
  logger.info waypoint.final_line
end