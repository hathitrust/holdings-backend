# frozen_string_literal: true

require "services"
require "cluster"
require "cluster_overlap"
require "utils/waypoint"

module Reports

  # Generates an overlap for a given member including copy counts
  class OverlapReport

    def initialize(org = nil, batch_size = 100_000)
      @org = org
      @waypoint = Utils::Waypoint.new(batch_size)
      @batch_size = batch_size
    end

    def overlap_line(overlap_hash)
      [overlap_hash[:lock_id],
       overlap_hash[:cluster_id],
       overlap_hash[:volume_id],
       overlap_hash[:n_enum],
       overlap_hash[:member_id],
       overlap_hash[:copy_count],
       overlap_hash[:brt_count],
       overlap_hash[:wd_count],
       overlap_hash[:lm_count],
       overlap_hash[:access_count]].join("\t")
    end

    def run
      logger = Services.logger
      logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum @batch_size}"

      ClusterOverlap.matching_clusters(@org).each do |c|
        ClusterOverlap.new(c, @org).each do |overlap|
          @waypoint.incr
          puts overlap_line(overlap.to_hash)
          @waypoint.on_batch {|wp| logger.info wp.batch_line }
        end
      end
      logger.info @waypoint.final_line
    end
  end
end
