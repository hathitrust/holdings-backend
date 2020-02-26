# frozen_string_literal: true

require 'mongoid'

# A member holding
class Holding
  include Mongoid::Document
  field :ocn, type: Integer#, type: OCLCNumber
  field :organization, type: String
  field :local_id, type: String
  field :enum_chron, type: String
  field :status, type: String
  field :condition, type: String
  field :gov_doc_flag, type: Boolean
  field :mono_multi_serial, type: String
  field :date_received, type: DateTime

  belongs_to :cluster

end 
