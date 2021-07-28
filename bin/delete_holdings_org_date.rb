# frozen_string_literal: true

require "services"
require "cluster"
require "date"

Services.mongo!

org = ARGV[0]
date = Date.parse(ARGV[1])
result = Cluster.collection.update_many({},
                                        { "$pull" =>
                                          { "holdings" =>
                                                          { "$and" => [
                                                            { "organization" => org },
                                                            { "date_received" => date }
                                                          ] } } })
puts result.inspect
