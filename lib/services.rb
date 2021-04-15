# frozen_string_literal: true

require "canister"
require "holdings_db"
require "ht_collections"
require "ht_members"
require "serials_file"
require "logger"
require "large_clusters"

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

Services.register(:serials) { SerialsFile.new(ENV["SERIALS_FILE"]) }
Services.register(:large_clusters) { LargeClusters.new }
Services.register(:hathifile_path) { Pathname.new(ENV["HATHIFILE_PATH"]) }
