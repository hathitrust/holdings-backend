# frozen_string_literal: true

require "active_record"

module Clusterable
  # A mapping from a deprecated OCN to a resolved OCN
  class OCN < ActiveRecord::Base
    self.table_name = "cluster_ocns"

    belongs_to :cluster

    def ==(other)
      self.class == other.class && self.id == other.id
    end

    def to_i
      ocn
    end
  end
end
