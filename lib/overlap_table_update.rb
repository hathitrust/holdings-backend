# frozen_string_literal: true

require "services"
require "utils/waypoint"
require "date"
require "cluster_update"

# An update of the table used for ETAS: holdings_htitem_htmember
class OverlapTableUpdate
  attr_accessor :cutoff_date, :waypoint, :num_deletes, :num_adds

  def initialize(cutoff_date = nil, batch_size = 100_000)
    @cutoff_date = cutoff_date || Date.today - 1.5
    @waypoint = Utils::Waypoint.new(batch_size)
    @num_deletes = 0
    @num_adds = 0
  end

  def keep_alive(session, seconds = 120)
    Thread.new do
      loop do
        sleep(seconds)
        session.client.command(refreshSessions: [session.session_id])
      end
    end
  end

  def overlap_table
    Services.relational_overlap_table
  end

  def run
    cutoff_str = cutoff_date.strftime("%Y-%m-%d %H:%M:%S")
    Services.logger.info "Upserting clusters last_modified after\
#{cutoff_str} to holdings_htitem_htmember"
    Cluster.with_session do |session|
      session_refresh = keep_alive(session)
      Cluster.where("ht_items.0": { "$exists": 1 },
                    last_modified: { "$gt": cutoff_date }).no_timeout.each do |cluster|
                      upsert_and_track cluster
                    end
      session_refresh.exit
    end
    Services.logger.info waypoint.final_line
  end

  private

  def upsert_and_track(cluster)
    Services.logger.debug("Processing overlap for cluster: #{cluster._id}")
    cu = ETAS::ClusterUpdate.new(overlap_table, cluster)
    #cu.upsert
    waypoint.incr(cu.deletes.count + cu.adds.count)
    waypoint.on_batch {|wp| Services.logger.info wp.batch_line }
    @num_deletes += cu.deletes.count
    @num_adds += cu.adds.count
  end
end
