# frozen_string_literal: true

require "canister"
require "settings"
require "mongoid"
require "holdings_db"
require "ht_collections"
require "ht_members"
require "serials_file"
require "logger"
require "large_clusters"

Services = Canister.new
Services.register(:"mongo!") do
  Mongoid.load!("mongoid.yml", Settings.environment)
end

Services.register(:slack_writer) { SlackWriter.new(Settings.slack_endpoint) }
Services.register(:holdings_db) { HoldingsDB.new }
Services.register(:ht_members) { HTMembers.new }
Services.register(:ht_collections) { HTCollections.new }
Services.register(:logger) do
  Logger.new($stderr, level: Logger::INFO)
end

Services.register(:serials) { SerialsFile.new(Settings.serials_file) }
Services.register(:large_clusters) { LargeClusters.new }
