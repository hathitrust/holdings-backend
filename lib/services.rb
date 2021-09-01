# frozen_string_literal: true

require "settings"

require "canister"
require "file_mutex"
require "logger"
require "mongoid"
require "utils/slack_writer"
require "data_sources"

Services = Canister.new
Services.register(:"mongo!") do
  Mongoid.load!("mongoid.yml", Settings.environment)
end

Services.register(:slack_writer) { Utils::SlackWriter.new(Settings.slack_endpoint) }
Services.register(:holdings_db) { DataSources::HoldingsDB.new }
Services.register(:ht_members) { DataSources::HTMembers.new }
Services.register(:ht_collections) { DataSources::HTCollections.new }
Services.register(:logger) do
  Logger.new($stderr, level: Logger::INFO)
end

Services.register(:serials) { DataSources::SerialsFile.new(Settings.serials_file) }

# Re-register with path once you know it.
Services.register(:scrub_logger) do
  Logger.new($stderr)
end

Services.register(:scrub_stats) { {} }

Services.register(:large_clusters) { DataSources::LargeClusters.new }
Services.register(:loading_flag) { FileMutex.new(Settings.loading_flag_path) }
