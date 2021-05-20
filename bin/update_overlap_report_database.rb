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

# At some future date we might want to update a single org's overlaps
def org
  nil
end

def upsert(overlap)
  rec = overlap_table.where(:volume_id => overlap[:volume_id], :member_id => overlap[:member_id])
  if 1 != rec.update(overlap)
    overlap_table.insert(overlap)
  end
end

# Default: Now - 36 hours 
cutoff_date = Date.today - 1.5

unless ARGV.empty?
  cutoff_date = Date.parse(ARGV.shift)
end

puts "Upserting clusters last_modified after #{cutoff_date.strftime("%Y-%m-%d %H:%M:%S")}"

BATCH_SIZE = 1_000
waypoint = Utils::Waypoint.new(BATCH_SIZE)

logger = Services.logger
Cluster.where("ht_items.0": { "$exists": 1},
              last_modified: {"$gt":cutoff_date}).no_timeout.each do |c|
  ClusterOverlap.new(c, org).each do |overlap|
    waypoint.incr
    upsert(overlap)
    waypoint.on_batch {|wp| logger.info wp.batch_line }
  end
end
logger.info waypoint.final_line 
