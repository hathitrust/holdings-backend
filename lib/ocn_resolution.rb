# frozen_string_literal: true

require "mongoid"

# A mapping from a deprecated OCN to a resolved OCN
class OCNResolution
  include Mongoid::Document

  # store_in collection: "resolutions", database: "test", client: "default"
  field :deprecated
  field :resolved
  field :ocns, type: Array

  embedded_in :cluster
  validates :deprecated, uniqueness: true
  validates_presence_of :deprecated, :resolved, :ocns
  index(ocns: 1)

  scope :for_cluster, lambda {|_cluster|
    where(:$in => ocns)
  }

  def initialize(params = nil)
    super
    self.ocns = [deprecated, resolved]
  end

end
