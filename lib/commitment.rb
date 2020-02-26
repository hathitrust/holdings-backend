# frozen_string_literal: true

require 'mongoid'

# A commitment
class Commitment
  include Mongoid::Document
  field :ocn, type: Integer#, type: OCLCNumber

  belongs_to :cluster

end 
