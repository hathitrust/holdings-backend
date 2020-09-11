# frozen_string_literal: true

require "canister"
require "holdings_db"
require "ht_members"
require "ht_collections"

Services = Canister.new

Services.register(:holdings_db) { HoldingsDB.connection }
Services.register(:ht_members) { HTMembers.new }
Services.register(:ht_collections) { HTCollections.new }
