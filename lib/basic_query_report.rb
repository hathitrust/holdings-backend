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
  def aggregate(query, &block)
    Cluster.collection.aggregate(query, { "allowDiskUse": true }).each(&block)
  end
end
