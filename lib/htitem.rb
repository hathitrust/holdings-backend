# frozen_string_literal: true

require 'mongoid'

# An HT Item 
class HTItem
  include Mongoid::Document
  field :ocns, type: Array 
  field :item_id, type: String

  belongs_to :cluster

end 
