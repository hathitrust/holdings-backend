# frozen_string_literal: true

require "services"
require "cluster"

Services.mongo!

# Pass a mongodb query to the appropriate method
# and the results will be yielded to you
class BasicQueryReport
  # Usage:
  # query = { ... }
  # BasicQueryReport.new.aggregate(query) { |result| ... }
  def aggregate(query, &)
    # We may have to change to allowDiskUse if/when we upgrade Mongo & mongo drivers,
    # because that seems like the more current lingo.
    Cluster.collection.aggregate(query, {allow_disk_use: true}).each(&)
  end
end
