# frozen_string_literal: true

require "settings"

require "canister"
require "file_mutex"
require "logger"
require "mongoid"
require "utils/push_metrics_marker"
require "data_sources/holdings_db"
require "data_sources/ht_collections"
require "data_sources/ht_organizations"
require "data_sources/large_clusters"
require "prometheus/client/push"

Services = Canister.new
Services.register(:mongo!) do
  Mongoid.load!(File.join(__dir__, "..", "config", "mongoid.yml"), Settings.environment)
end

Services.register(:holdings_db) { DataSources::HoldingsDB.new }
Services.register(:relational_overlap_table) { Services.holdings_db[:holdings_htitem_htmember] }
Services.register(:ht_organizations) { DataSources::HTOrganizations.new }
Services.register(:ht_collections) { DataSources::HTCollections.new }
Services.register(:logger) do
  Logger.new($stderr, level: Logger::INFO)
end

# Re-register with path once you know it.
Services.register(:scrub_logger) do
  Logger.new($stderr)
end

Services.register(:scrub_stats) { {} }

Services.register(:large_clusters) { DataSources::LargeClusters.new }
Services.register(:loading_flag) { FileMutex.new(Settings.loading_flag_path) }

Services.register(:pushgateway) { Prometheus::Client::Push.new(job: File.basename($PROGRAM_NAME), gateway: Settings.pushgateway) }
Services.register(:prometheus_registry) { Prometheus::Client.registry }
Services.register(:prometheus_metrics) do
  {
    duration: Prometheus::Client::Gauge.new(:job_duration_seconds,
      docstring: "Time spend running job in seconds"),

    last_success: Prometheus::Client::Gauge.new(:job_last_success,
      docstring: "Last Unix time when job successfully completed"),

    records_processed: Prometheus::Client::Gauge.new(:job_records_processed,
      docstring: "Records processed by job"),
    success_interval: Prometheus::Client::Gauge.new(:job_expected_success_interval,
      docstring: "Maximum expected time in seconds between job completions")
  }.tap { |m| m.each_value { |metric| Services.prometheus_registry.register(metric) } }
end

Services.register(:progress_tracker) { Utils::PushMetricsMarker }
Services.register(:redis_config) { raise "Redis not configured" }
