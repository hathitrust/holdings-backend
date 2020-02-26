# frozen_string_literal: true

require "mongoid"

# An HT Item
class HTItem
  include Mongoid::Document
  field :ocns, type: Array
  field :item_id, type: String

  embedded_in :cluster

  def move(new_parent)
    unless new_parent.id == _parent.id
      new_parent.h_t_items << dup
      delete
    end
  end

end
