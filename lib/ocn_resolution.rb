# frozen_string_literal: true

require "mongoid"

# A mapping from a deprecated OCN to a resolved OCN
class OCNResolution
  include Mongoid::Document

  store_in collection: "resolutions", database: "test", client: "default"
  field :deprecated
  field :resolved

  index({ deprecated: 1 }, unique: true)
  index(resolved: 1)

  scope :for_cluster, lambda {|cluster|
    where(:$or => [:deprecated.in => cluster.ocns,
                   :resolved.in   => cluster.ocns])
  }
end
