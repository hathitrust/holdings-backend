# frozen_string_literal: true

require "mongoid"

# An HT Item
class HtItem
  include Mongoid::Document
  field :ocns, type: Array
  field :item_id, type: String

  embedded_in :cluster

  def move(new_parent)
    unless new_parent.id == _parent.id
      new_parent.ht_items << dup
      delete
    end
  end

end
