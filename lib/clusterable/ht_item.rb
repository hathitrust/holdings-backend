# frozen_string_literal: true

require "mongoid"
require "enum_chron"
require "services"

module Clusterable
  # An HT Item
  # - ocns
  # - item_id
  # - ht_bib_key
  # - rights
  # - bib_fmt
  # - enum_chron
  # - n_enum
  # - n_chron
  # - collection_code
  # - billing_entity
  class HtItem
    include Mongoid::Document
    include EnumChron
    field :ocns, type: Array, default: []
    field :item_id, type: String
    field :ht_bib_key, type: Integer
    field :rights, type: String
    field :access, type: String
    field :bib_fmt, type: String
    field :enum_chron, type: String, default: ""
    field :n_enum, type: String, default: ""
    field :n_chron, type: String, default: ""
    field :n_enum_chron, type: String, default: ""
    field :collection_code, type: String
    field :billing_entity, type: String

    embedded_in :cluster
    validates :item_id, uniqueness: true
    validates_presence_of :item_id, :ht_bib_key, :rights, :bib_fmt, :access

    validates_each :ocns do |record, attr, value|
      value.each do |ocn|
        record.errors.add attr, "must be an integer" \
          unless (ocn.to_i if /\A[+-]?\d+\Z/.match?(ocn.to_s))
      end
    end

    def initialize(params = nil)
      super
      set_billing_entity if collection_code
    end

    def collection_code=(collection_code)
      super
      set_billing_entity
    end

    def to_hash
      attributes.with_indifferent_access.except(:_id)
    end

    def batch_with?(other)
      return false if ocns.empty?

      ocns == other.ocns
    end

    private

    def set_billing_entity
      self.billing_entity = Services.ht_collections[collection_code].billing_entity
    end

  end
end
