# frozen_string_literal: true

require "settings"

require "canister"
require "file_mutex"
require "holdings_db"
require "ht_collections"
require "ht_members"
require "large_clusters"
require "logger"
require "mongoid"
require "serials_file"
require "utils/slack_writer"

Services = Canister.new
Services.register(:"mongo!") do
  Mongoid.load!("mongoid.yml", Settings.environment)
end

Services.register(:slack_writer) { Utils::SlackWriter.new(Settings.slack_endpoint) }
Services.register(:holdings_db) { HoldingsDB.new }
Services.register(:ht_members) { HTMembers.new }
Services.register(:ht_collections) { HTCollections.new }
Services.register(:logger) do
  Logger.new($stderr, level: Logger::INFO)
end

Services.register(:serials) { SerialsFile.new(Settings.serials_file) }

# Re-register with path once you know it.
Services.register(:scrub_logger) do
  Logger.new($stderr)
end

Services.register(:scrub_stats) { {} }

Services.register(:large_clusters) { LargeClusters.new }
Services.register(:loading_flag) { FileMutex.new(Settings.loading_flag_path) }
