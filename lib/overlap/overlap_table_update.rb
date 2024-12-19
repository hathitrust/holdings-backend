# frozen_string_literal: true

require "services"
require "date"
require "cluster_update"

module Overlap
  # An update of the table used for ETAS: holdings_htitem_htmember
  class OverlapTableUpdate
    attr_accessor :cutoff_date, :marker, :num_deletes, :num_adds

    def initialize(cutoff_date = nil, batch_size = 100_000)
      @cutoff_date = cutoff_date || Date.today - 1.5
      @marker = Services.progress_tracker.call(batch_size: batch_size)
      @num_deletes = 0
      @num_adds = 0
    end

    def overlap_table
      Services.relational_overlap_table
    end

    def run
      raise "not implemented"
      cutoff_str = cutoff_date.strftime("%Y-%m-%d %H:%M:%S")
      Services.logger.info "Upserting clusters last_modified after\
      #{cutoff_str} to holdings_htitem_htmember"
      Utils::SessionKeepAlive.new(120).run do
        Cluster.batch_size(Settings.etas_overlap_batch_size)
          .where("ht_items.0": {"$exists": 1},
            last_modified: {"$gt": cutoff_date}).no_timeout.each do |cluster|
          upsert_and_track cluster
        end
      end
      Services.logger.info marker.final_line
    end

    private

    def upsert_and_track(cluster)
      Services.logger.debug("Processing overlap for cluster: #{cluster._id}")
      cu = ClusterUpdate.new(overlap_table, cluster)
      cu.upsert
      marker.incr(cu.deletes.count + cu.adds.count)
      marker.on_batch do |m|
        Services.logger.info m.batch_line
      end
      @num_deletes += cu.deletes.count
      @num_adds += cu.adds.count
    end
  end
end
