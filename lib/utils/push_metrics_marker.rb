# frozen_string_literal: true

require "services"
require "milemarker"
require "delegate"

module Utils
  # Adds prometheus push exporter to Milemarker that tracks:
  #   - number of items processed
  #   - time running so far
  #   - success time
  class PushMetricsMarker < SimpleDelegator
    def initialize(batch_size,
      marker: Milemarker.new(batch_size: batch_size),
      registry: Services.prometheus_registry,
      metrics: Services.prometheus_metrics,
      pushgateway: Services.pushgateway,
      success_interval: ENV["JOB_SUCCESS_INTERVAL"])
      @marker = marker
      @pushgateway = pushgateway
      @registry = registry
      @metrics = metrics

      super(@marker)

      if success_interval
        metrics[:success_interval].set(success_interval.to_i)
      end

      update_metrics
    end

    def final_line
      metrics[:last_success].set(Time.now.to_i)
      update_metrics
      marker.final_line
    end

    def on_batch
      marker.on_batch do |wp|
        yield wp
        update_metrics
      end
    end

    private

    attr_reader :marker, :pushgateway, :registry, :metrics

    def update_metrics
      metrics[:duration].set(@marker.total_seconds_so_far)
      metrics[:records_processed].set(@marker.count)
      pushgateway.add(registry)
    end
  end
end
