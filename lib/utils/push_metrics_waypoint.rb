# frozen_string_literal: true

require "services"
require "utils/waypoint"
require "delegate"

module Utils
  # Adds prometheus push exporter to Waypoint that tracks:
  #   - number of items processed
  #   - time running so far
  #   - success time
  class PushMetricsWaypoint < SimpleDelegator
    def initialize(batch_size,
      waypoint: Utils::Waypoint.new(batch_size),
      registry: Services.prometheus_registry,
      metrics: Services.prometheus_metrics,
      pushgateway: Services.pushgateway,
      success_interval: ENV["JOB_SUCCESS_INTERVAL"])
      @waypoint = waypoint
      @pushgateway = pushgateway
      @registry = registry
      @metrics = metrics

      super(@waypoint)

      if success_interval
        metrics[:success_interval].set(success_interval.to_i)
      end

      update_metrics
    end

    def finalize
      waypoint.finalize
      metrics[:last_success].set(Time.now.to_i)
      update_metrics
    end

    def on_batch
      waypoint.on_batch do |wp|
        yield wp
        update_metrics
      end
    end

    private

    attr_reader :waypoint, :pushgateway, :registry, :metrics

    def update_metrics
      metrics[:duration].set(@waypoint.total_seconds_so_far)
      metrics[:records_processed].set(@waypoint.count)
      pushgateway.add(registry)
    end
  end
end
