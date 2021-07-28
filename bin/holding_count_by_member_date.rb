# frozen_string_literal: true

require "services"
require "cluster"

Services.mongo!

Cluster.collection.aggregate([
  { "$unwind" => "$holdings" },
  { "$project" =>
    { "organization_date":
      { "$concat":
        [
          "$holdings.organization",
          "\t",
          { "$dateToString" => { "date"   => "$holdings.date_received",
                                 "format" => "%Y-%m-%d" } }
      ] } } },
      { "$group" => { "_id" => "$organization_date", "count" => { "$sum" => 1 } } }
]).each do |r|
  puts r.values.join("\t")
end
