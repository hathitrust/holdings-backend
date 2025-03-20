# frozen_string_literal: true

module Clusterable
  # A mapping from a deprecated/variant OCN to a resolved/canonical OCN
  class OCNResolution < Clusterable::Base
    attr_accessor :variant, :canonical

    def self.table
      Services.concordance_table
    end

    def self.with_ocns(ocns, cluster: nil)
      return to_enum(__method__, ocns) unless block_given?

      ocns = ocns.to_a
      dataset = table.where(variant: ocns).or(canonical: ocns)

      dataset.each do |row|
        yield new(variant: row[:variant], canonical: row[:canonical], cluster: cluster)
      end
    end

    # Returns the given OCNs and any variant or canonical OCNs the given OCNs
    # map to, as a Set
    def self.concordanced_ocns(ocns)
      ocn_query = ocns.map(&:to_s).uniq
      # and gather all OCNs that concordance to those OCNs
      o2_variant = Sequel.qualify(:o2, :variant)
      o2_canonical = Sequel.qualify(:o2, :canonical)
      o1_variant = Sequel.qualify(:o1, :variant)
      o1_canonical = Sequel.qualify(:o1, :canonical)

      concordance_ocns =
        table.db
          .select(o2_variant, o2_canonical)
          .from(Sequel.as(:oclc_concordance, :o1), Sequel.as(:oclc_concordance, :o2))
          .where(o1_canonical => o2_canonical)
          .where(Sequel.or(
            o1_canonical => ocn_query,
            o1_variant => ocn_query
          )).to_a

      all_ocns = (ocns + concordance_ocns.map { |o| o[:variant] } + concordance_ocns.map { |o| o[:canonical] })

      all_ocns.flatten.map(&:to_i).to_set
    end

    def cluster
      @cluster ||= Cluster.for_ocns(ocns)
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
