# frozen_string_literal: true

require "services"
require "cluster"

Services.mongo!

org = ARGV[0]
date = Date.parse(ARGV[1])

Cluster.collection.aggregate([
  { '$unwind' => '$holdings' },
  { '$match' => { "$and": [ { "holdings.organization" => org }, { "holdings.date_received" => date } ] } }
]).each do |r|
  puts r["holdings"].slice(:ocn, :local_id, :organization, :date_received, :uuid).values.join("\t")
end

