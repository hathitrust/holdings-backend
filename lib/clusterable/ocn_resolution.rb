# frozen_string_literal: true

require "active_record"

module Clusterable
  # A mapping from a deprecated OCN to a resolved OCN
  class OCNResolution < ActiveRecord::Base

    # store_in collection: "resolutions", database: "test", client: "default"
#    field :deprecated
#    field :resolved
#    field :ocns, type: Array

    belongs_to :cluster
    validates :deprecated, uniqueness: true
    validates_presence_of :deprecated, :resolved, :ocns
#    index(ocns: 1)

    scope :for_cluster, lambda { |_cluster|
      where(:$in => ocns)
    }

    def ==(other)
      self.class == other.class && deprecated == other.deprecated && resolved == other.resolved
    end

    def initialize(params = nil)
      super
      self.ocns = [deprecated, resolved]
    end

    def batch_with?(other)
      resolved == other.resolved
    end
  end
end
