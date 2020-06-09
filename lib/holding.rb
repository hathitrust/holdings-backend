# frozen_string_literal: true

require "mongoid"

# A member holding
class Holding
  include Mongoid::Document
  field :ocn, type: Integer
  field :organization, type: String
  field :local_id, type: String
  field :enum_chron, type: String
  field :status, type: String
  field :condition, type: String
  field :gov_doc_flag, type: Boolean
  field :mono_multi_serial, type: String
  field :date_received, type: DateTime

  embedded_in :cluster

  validates_presence_of :ocn, :organization, :mono_multi_serial, :date_received
  validates_inclusion_of :mono_multi_serial, in: ["mono", "multi", "serial"]

end
