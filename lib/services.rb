# frozen_string_literal: true

require "settings"

require "canister"
require "file_mutex"
require "logger"
require "push_metrics"
require "data_sources/holdings_db"
require "data_sources/ht_collections"
require "data_sources/ht_organizations"
require "prometheus/client/push"

Services = Canister.new

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

Services.register(:loading_flag) { FileMutex.new(Settings.loading_flag_path) }

Services.register(:prometheus_registry) { Prometheus::Client.registry }
Services.register(:pushgateway) { Prometheus::Client::Push.new(job: File.basename($PROGRAM_NAME), gateway: Settings.pushgateway) }
Services.register(:progress_tracker) do
  ->(**kwargs) do
    PushMetrics.new(registry: Services.prometheus_registry,
      pushgateway: Services.pushgateway,
                    **kwargs)
  end
end
Services.register(:redis_config) { raise "Redis not configured" }
