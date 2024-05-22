# frozen_string_literal: true


Services.mongo!

class CleanupDuplicateHoldings
  LOG_INTERVAL = 60

  def initialize
    @clusters_processed = 0
    @old_holdings_processed = 0
    @new_holdings_processed = 0
    @last_log_time = Time.now
    Services.logger.info("Starting cluster deduplication")
  end


  def run
    Cluster.each do |cluster|
      Services.logger.debug("Cleaning cluster #{cluster._id}: #{cluster.ocns}")
      old_count = cluster.holdings.count
      new_count = remove_duplicate_holdings(cluster)
      update_progress(old_count, new_count)
    end

    Services.logger.info("Finished cleaning clusters")
    log_progress
  end

  private

  def update_progress(old_count, new_count)
    @clusters_processed += 1
    @old_holdings_processed += old_count
    @new_holdings_processed += new_count

    log_progress if hasnt_logged_recently?
  end

  def log_progress
    Services.logger.info("Processed #{@clusters_processed} clusters")
    Services.logger.info("Processed #{@old_holdings_processed} old holdings")
    Services.logger.info("Kept #{@new_holdings_processed} holdings")
    @last_log_time = Time.now
  end

  def hasnt_logged_recently?
    !@last_log_time or (Time.now - @last_log_time > LOG_INTERVAL)
  end

  # Returns the count of deduped holdings
  def remove_duplicate_holdings(cluster)
    cluster.holdings = dedupe_holdings(cluster)
    cluster.save
    cluster.holdings.count
  end

  def dedupe_holdings(cluster)
    cluster.holdings.group_by(&:update_key).map do |update_key,holdings_group| 
      latest_date = holdings_group.map(&:date_received).max
      holdings_group.reject { |h| h.date_received != latest_date }
    end.flatten
  end
end

if __FILE__ == $PROGRAM_NAME
  CleanupDuplicateHoldings.new(ARGV).run
end
