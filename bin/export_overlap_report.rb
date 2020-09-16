#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "bundler/setup"
require "ocn_resolution"
require "holding"
require "utils/waypoint"
require "utils/ppnum"
require "zinzout"
require "cluster_overlap"

Mongoid.load!("mongoid.yml", :test)

# Find clusters that match the given org or all
def matching_clusters(org = nil)
  if org.nil?
    Cluster.where("ht_items.0": { "$exists": 1 })
  else
    Cluster.where("ht_items.0": { "$exists": 1 },
              "$or": [{ "holdings.organization": org },
                      { "ht_items.billing_entity": org }])
  end
end

def overlap_line(overlap_hash)
  [overlap_hash[:cluster_id],
   overlap_hash[:volume_id],
   overlap_hash[:member_id],
   overlap_hash[:copy_count],
   overlap_hash[:brt_count],
   overlap_hash[:wd_count],
   overlap_hash[:lm_count],
   overlap_hash[:access_count]].join("\t")
end

if __FILE__ == $PROGRAM_NAME
  BATCH_SIZE = 10_000
  waypoint = Utils::Waypoint.new(BATCH_SIZE)
  logger = Services.logger
  logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum BATCH_SIZE}"

  org = ARGV.shift
  matching_clusters(org).each do |c|
    ClusterOverlap.new(c, org).each do |overlap|
      waypoint.incr
      puts overlap_line(overlap.to_hash)
      waypoint.on_batch {|wp| logger.info wp.batch_line }
    end
  end
  logger.info waypoint.final_line
end
