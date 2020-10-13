# frozen_string_literal: true

require "canister"
require "holdings_db"
require "ht_collections"
require "ht_members"
require "logger"

Services = Canister.new
Services.register(:"mongo!") do
  Mongoid.load!("mongoid.yml", ENV["MONGOID_ENV"] || :development)
end

Services.register(:holdings_db) { HoldingsDB.new }
Services.register(:ht_members) { HTMembers.new }
Services.register(:ht_collections) { HTCollections.new }
Services.register(:logger) do
  Logger.new($stderr).tap do |l|
    l.level = Logger::INFO
  end
end
