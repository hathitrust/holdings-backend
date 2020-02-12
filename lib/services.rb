# frozen_string_literal: true

require "canister"
require "mongo"

Services = Canister.new

Services.register(:cluster_collection) do |_c|
  Mongo::Client.new(ENV["MONGO_URL"])[:clusters]
end
