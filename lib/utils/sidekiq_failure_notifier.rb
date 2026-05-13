# frozen_string_literal: true

require "utils/slack_notifier"

module Utils
  module SidekiqFailureNotifier
    # retry_count is nil on 1st attempt, 0 on 2nd, 1 on 3rd — notify on 3rd failure
    NOTIFY_AT_RETRY_COUNT = 1

    def self.alerts_url
      Settings.slack_alerts_webhook_url
    end

    def self.failure_message(job, exception)
      "Sidekiq job failed (will retry): #{job["class"]}\n" \
        "Args: #{job["args"].inspect}\n" \
        "Error: #{exception.class}: #{exception.message}"
    end

    def self.death_message(job, exception)
      "Sidekiq job failed (no more retries): #{job["class"]}\n" \
        "Args: #{job["args"].inspect}\n" \
        "Error: #{exception.class}: #{exception.message}"
    end

    class Middleware
      def call(_worker, job, _queue)
        yield
      rescue => e
        if job["retry_count"] == NOTIFY_AT_RETRY_COUNT
          Utils::SlackNotifier.post(
            SidekiqFailureNotifier.failure_message(job, e),
            url: SidekiqFailureNotifier.alerts_url
          )
        end
        raise
      end
    end
  end
end
