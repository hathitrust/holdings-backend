# frozen_string_literal: true

require "mongoid"

# A commitment
class Commitment
  include Mongoid::Document
  field :ocn, type: Integer # , type: OCLCNumber
  field :organization, type: String

  embedded_in :cluster

  def move(new_parent)
    unless new_parent.id == _parent.id
      new_parent.commitments << dup
      delete
    end
  end

end
