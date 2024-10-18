require "services"
require "cluster"

class MongoUpdater
  # Convenience method for writing otherwise quite clunky update queries
  # for embedded documents. The somewhat simpler:
  # MongoUpdater.update_embedded(
  #   clusterable: "holdings",
  #   matcher: {"mono_multi_serial": "mono"},
  #   updater: {"mono_multi_serial": "spm"}
  # )
  # Evaluates to the somewhat more complex:
  # Cluster.collection.update_many(
  #   {"holdingss"=>{"$elemMatch"=>{:mono_multi_serial=>"mono"}}},
  #   {"$set"=>{"holdings.$[x].mono_multi_serial"=>"spm"}},
  #   {"array_filters"=>[{"x.mono_multi_serial"=>"mono"}]}
  # )
  # ... and is orders of magnitude {citation needed} faster than
  # Cluster.where(...).each do |cluster| cluster.x.each do |x| x.field = y end end
  def self.update_embedded(
    clusterable: "", # "commitments", "holdings", "ht_items"
    matcher: {}, # key-value hash(es) for finding the clusterable(s)
    updater: {} # key-value hash(es) with new values
  )

    if clusterable.empty?
      raise ArgumentError,
        "Need a string indicating a clusterable ('commitments', 'holdings', etc.)"
    end

    raise "not implemented"
  end
end
