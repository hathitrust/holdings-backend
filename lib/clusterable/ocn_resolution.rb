# frozen_string_literal: true

module Clusterable
  # A mapping from a deprecated/variant OCN to a resolved/canonical OCN
  class OCNResolution < Clusterable::Base
    attr_accessor :variant, :canonical
    #    include Mongoid::Document
    #
    #    # store_in collection: "resolutions", database: "test", client: "default"
    #    field :deprecated
    #    field :resolved
    #    field :ocns, type: Array
    #
    #    embedded_in :cluster
    #    validates :deprecated, uniqueness: true
    #    validates_presence_of :deprecated, :resolved, :ocns
    #    index(ocns: 1)
    #
    #    scope :for_cluster, lambda { |_cluster|
    #      where(:$in => ocns)
    #    }
    #
    def self.table
      Services[:holdings_db][:oclc_concordance]
    end

    def self.with_ocns(ocns)
      return to_enum(__method__, ocns) unless block_given?

      ocns = ocns.to_a
      dataset = table.where(variant: ocns).or(canonical: ocns)

      dataset.each do |row|
        yield new(variant: row[:variant], canonical: row[:canonical])
      end
    end

    def cluster
      Cluster.for_ocns(ocns).first
    end

    def table
      self.class.table
    end

    def ocns
      [variant, canonical]
    end

    def batch_with?(other)
      canonical == other.canonical
    end

    def save
      # TBD -- is this class responsible for loading or
      # will this be pre-loaded by some batch thing?? How will we construct the
      # clustering if so?
      #
      # Use replace rather than insert so if the row already exists, this is a
      # no-op.
      table.replace([:variant, :canonical], [variant, canonical])
    end

    alias_method :save!, :save
  end
end
