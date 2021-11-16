#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"
require "settings"
require "utils/waypoint"
require "utils/ppnum"
require "zinzout"
require "overlap/cluster_overlap"

def main
  Services.mongo!

  batch_size = 100_000
  waypoint = Services.progress_tracker.new(batch_size)
  logger = Services.logger

  Cluster.where("ht_items.0": { "$exists": 1 }).no_timeout.each do |cluster|
    Overlap::ClusterOverlap.new(cluster, nil).each do |overlap|
      waypoint.incr
      oh = overlap.to_hash
      puts [oh[:lock_id],
            oh[:cluster_id],
            oh[:volume_id],
            oh[:n_enum],
            oh[:member_id],
            oh[:copy_count],
            oh[:brt_count],
            oh[:wd_count],
            oh[:lm_count],
            oh[:access_count]].join("\t")
      waypoint.on_batch {|wp| logger.info wp.batch_line }
    end
  end
end

main if $PROGRAM_NAME == __FILE__
