#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"
require "settings"
require "utils/waypoint"
require "utils/ppnum"
require "zinzout"
require "cluster_overlap"
require "etas_overlap"

Services.mongo!

if __FILE__ == $PROGRAM_NAME
  BATCH_SIZE = 100_000
  waypoint = Utils::Waypoint.new(BATCH_SIZE)
  logger = Services.logger

  Cluster.where("ht_items.0": { "$exists": 1 }).no_timeout.each do |cluster|
    ClusterOverlap.new(cluster, nil).each do |overlap|
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
