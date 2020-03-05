# frozen_string_literal: true

require "mongoid"

# A mapping from a deprecated OCN to a resolved OCN
class OCNResolution
  include Mongoid::Document

  store_in collection: "resolutions", database: "test", client: "default"
  field :deprecated
  field :resolved

  index({ deprecated: 1}, unique: true )
  index({ resolved: 1 })

  def same_rule?(other)
    self.deprecated == other.deprecated &&
      self.resolved == other.resolved
  end

end
