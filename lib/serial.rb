# frozen_string_literal: true

require "mongoid"

# A print serial record
# Used in the process to determine item type
class Serial
  include Mongoid::Document
  field :record_id, type: Integer
  field :ocns, type: Array
  field :issns, type: Array
  field :locations, type: String

  embedded_in :cluster

  validates_presence_of :ocns, :record_id

end
