require "services"
require "cluster"

Services.mongo!

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

    # Updater passed in here in the form: {"field1": "val"}
    # And we update it to what mongo requires, i.e.:
    # {"#{clusterable}.$[x].field1": "val"}
    # or else the arryFilters part doesn't work.
    updater.keys.each do |k|
      unless k.start_with?("#{clusterable}.$[x].")
        updater["#{clusterable}.$[x].#{k}"] = updater.delete(k)
      end
    end

    query = [
      {clusterable => {"$elemMatch" => matcher}},
      # Hardcoding $set, so anything needing $push will not work out of the box.
      {"$set" => updater}
    ]
    # The array filter hash can be derived from the matcher, like so:
    if matcher.any?
      # ... adding the same "x." prefix as used in updater.
      query << {
        "array_filters" => [
          matcher.map { |k, v| ["x.#{k}", v] }.to_h
        ]
      }
    end
    # puts query.inspect
    Cluster.collection.update_many(*query)
  end
end
