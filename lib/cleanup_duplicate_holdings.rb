# frozen_string_literal: true

require "services"
require "cluster"
require "sidekiq"
require "milemarker"

class CleanupDuplicateHoldings
  include Sidekiq::Job
  JOB_CLUSTER_COUNT = 100

  def self.queue_jobs(job_cluster_count: JOB_CLUSTER_COUNT)
    milemarker = Milemarker.new(name: "Queue clusters", batch_size: 50_000)
    milemarker.logger = Services.logger

    # Iterate over batches of clusters of size job_cluster_count, and queue
    # a job for each batch.
    #
    # We need the "each" in there to turn it into an iterable
    # such that "each_slice" will work performantly (i.e. without trying to
    # fetch all the results)
    Cluster.only(:id).each.each_slice(job_cluster_count) do |batch|
      cluster_ids = batch.map(&:_id).map(&:to_s)
      # Queues a job of this class
      perform_async(cluster_ids)

      milemarker.incr(job_cluster_count).on_batch do
        Services.logger.info milemarker.batch_line
      end
    end

    milemarker.log_final_line
  end

  def initialize
    @clusters_processed = 0
    @old_holdings_processed = 0
    @new_holdings_processed = 0
    @last_log_time = Time.now
  end

  def perform(cluster_ids)
    cluster_ids.each do |cluster_id|
      cluster = Cluster.find(_id: cluster_id)
      Services.logger.info("Cleaning cluster #{cluster._id}: #{cluster.ocns}")
      old_count = cluster.holdings.count
      remove_duplicate_holdings(cluster)
      new_count = cluster.holdings.count
      update_progress(old_count, new_count)
      Thread.pass
    end

    Services.logger.info("Processed #{@clusters_processed} clusters, #{@old_holdings_processed} old holdings, kept #{@new_holdings_processed} holdings")
  end

  private

  def update_progress(old_count, new_count)
    @clusters_processed += 1
    @old_holdings_processed += old_count
    @new_holdings_processed += new_count
  end

  # Returns the count of deduped holdings
  def remove_duplicate_holdings(cluster)
    rejected_count = 0

    deduped_holdings = cluster.holdings.group_by(&:update_key).map do |update_key, holdings_group|
      latest_date = holdings_group.map(&:date_received).max
      holdings_group.reject { |h| h.date_received != latest_date && rejected_count += 1 }
    end.flatten

    if rejected_count > 0
      cluster.holdings = deduped_holdings
      cluster.save
    end
  end
end
