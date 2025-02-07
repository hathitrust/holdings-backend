# frozen_string_literal: true

require "clusterable/base"
require "services"
require "enum_chron"
require "ocnless_cluster"

module Clusterable
  class HtItem < Clusterable::Base
    include EnumChron

    IC_RIGHTS_CODES = %w[ic op und nobody pd-pvt].freeze

    attr_accessor :ocns, :item_id, :ht_bib_key, :rights, :access, :bib_fmt,
      :n_enum, :n_chron, :n_enum_chron, :billing_entity

    attr_reader :collection_code, :enum_chron

    class << self
      def table
        Services.hathifiles_table
      end

      def with_ocns(ocns)
        return to_enum(__method__, ocns) unless block_given?

        ocns_dataset(ocns).each do |row|
          yield from_row(row)
        end
      end

      def ic_volumes
        return to_enum(__method__) unless block_given?

        table.where(rights_code: IC_RIGHTS_CODES).each do |row|
          yield from_row(row)
        end
      end

      def pd_count
        table.exclude(rights_code: IC_RIGHTS_CODES).count
      end

      def count
        table.count
      end

      def with_bib_key(bib_key)
        return to_enum(__method__, bib_key) unless block_given?

        table.where(bib_num: bib_key).each do |row|
          yield from_row(row)
        end
      end

      def find(item_id:, ocns: nil)
        dataset = dataset_for_query(item_id: item_id, ocns: ocns)
        from_row(dataset.first!)
      end

      def from_row(row)
        new({
          item_id: row[:htid],
          ht_bib_key: row[:bib_num],
          rights: row[:rights_code],
          access: row[:access] ? "allow" : "deny",
          bib_fmt: row[:bib_fmt],
          enum_chron: row[:description],
          collection_code: row[:collection_code],
          ocns: row[:oclc].split(",").map { |ocn| ocn.to_i }
        })
      end

      private

      def ocns_dataset(ocns)
        table.select { hf.* }
          .natural_join(:hf_oclc)
          .where(value: ocns.map(&:to_s))
          .group_by(:htid)
      end

      def dataset_for_query(item_id:, ocns:)
        ocn_or_base_table(ocns: ocns).where(htid: item_id)
      end

      def ocn_or_base_table(ocns:)
        if ocns
          ocns_dataset(ocns)
        else
          table
        end
      end
    end

    def cluster
      if ocns.none?
        return OCNLessCluster.new(bib_key: ht_bib_key)
      end
      clusters = Cluster.for_ocns(ocns)
      if clusters.count > 1
        raise "ocns #{ocns} for item #{item_id} match multiple clusters"
      else
        clusters.first
      end
    end

    def collection_code=(collection_code)
      @collection_code = collection_code
      set_billing_entity
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
