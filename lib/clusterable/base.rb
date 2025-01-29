# frozen_string_literal: true

require "enum_chron_parser"
require "services"

# Handles automatic normalization of enum_chron fields for Holdings and HTItems

module Clusterable
  class Base
    [:all_attrs, :equality_attrs, :equality_excluded_attr].each do |method|
      define_method(method) do
        self.class.public_send(method)
      end
    end

    def self.attr_writer(*attrs)
      super
      add_attrs(*attrs)
    end

    def self.attr_accessor(*attrs)
      super
      add_attrs(*attrs)
    end

    def self.attr_reader(*attrs)
      super
      add_attrs(*attrs)
    end

    def self.all_attrs
      @all_attrs ||= Set.new
    end

    def self.equality_attrs
      @all_attrs ||= Set.new
      @equality_excluded_attrs ||= Set.new
      @all_attrs - @equality_excluded_attrs
    end

    def self.equality_excluded_attr(*attrs)
      @equality_excluded_attrs ||= Set.new
      @equality_excluded_attrs.merge(attrs)
    end

    def self.add_attrs(*attrs)
      @all_attrs ||= Set.new
      @all_attrs.merge(attrs)
    end

    def initialize(params = {})
      params&.transform_keys!(&:to_sym)
      all_attrs.each do |attr|
        send(attr.to_s + "=", params[attr]) if params.has_key?(attr)
      end
    end

    def ==(other)
      compare(equality_attrs, other)
    end

    def same_as?(other)
      compare(all_attrs, other)
    end

    def update_key
      to_hash
        .slice(*equality_attrs)
        # fold blank strings & nil to same update key, as in
        # equality above
        .transform_values { |f| blank?(f) ? nil : f }
        .hash
    end

    def to_hash
      all_attrs.map { |a| [a, send(a)] }.to_h
    end

    private

    def compare(attrs, other)
      instance_of?(other.class) &&
        attrs.all? do |attr|
          self_attr = public_send(attr)
          other_attr = other.public_send(attr)

          (self_attr == other_attr) or (blank?(self_attr) and blank?(other_attr))
        end
    end

    def blank?(value)
      value == "" || value.nil?
    end
  end
end
