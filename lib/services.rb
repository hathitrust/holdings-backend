# frozen_string_literal: true

require "settings"

require "canister"
require "file_mutex"
require "logger"
require "push_metrics"
require "data_sources/mariadb"
require "data_sources/ht_collections"
require "data_sources/ht_organizations"
require "prometheus/client/push"

Services = Canister.new

Services.register(:holdings_db) { DataSources::MariaDB.new("HOLDINGS_RW") }
Services.register(:holdings_table) { Services.holdings_db[:holdings] }

Services.register(:ht_db) { DataSources::MariaDB.new("HT_RO") }
Services.register(:hathifiles_table) { Services.ht_db[:hf] }
Services.register(:hathifiles_ocn_table) { Services.ht_db[:hf_oclc] }
Services.register(:concordance_table) { Services.ht_db[:oclc_concordance] }
Services.register(:billing_members_table) { Services.ht_db[:ht_billing_members] }
Services.register(:collections_table) { Services.ht_db[:ht_collections] }

Services.register(:ht_organizations) { DataSources::HTOrganizations.new }
Services.register(:ht_collections) { DataSources::HTCollections.new }
Services.register(:logger) do
  level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
  Logger.new($stdout, level: level)
end

# Re-register with path once you know it.
Services.register(:scrub_logger) do
  Logger.new($stdout)
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
