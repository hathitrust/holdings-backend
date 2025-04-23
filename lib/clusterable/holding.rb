# frozen_string_literal: true

require "clusterable/base"
require "enum_chron"
require "json"
require "securerandom"
require "services"

module Clusterable
  # A holding
  class Holding < Clusterable::Base
    include EnumChron

    attr_accessor :ocn, :local_id, :organization, :n_enum, :n_chron,
      :n_enum_chron, :status, :condition, :gov_doc_flag, :mono_multi_serial,
      :uuid, :issn, :delete_flag

    equality_excluded_attr :uuid, :date_received

    attr_reader :date_received, :enum_chron

    def self.count
      table.count
    end

    def cluster
      @cluster ||= Cluster.for_ocns([ocn])
    end

    # validates_presence_of :ocn, :organization, :mono_multi_serial, :date_received
    # validates_inclusion_of :mono_multi_serial, in: ["mix", "mon", "spm", "mpm", "ser"]

    def brt_lm_access?
      condition == "BRT" || status == "LM"
    end

    # Convert a tsv line from a validated holding file into a record like hash
    #
    # @param holding_line, a tsv line
    def self.holding_to_record(holding_line)
      # OCN  BIB  MEMBER_ID  STATUS  CONDITION  DATE  ENUM_CHRON  TYPE  \
      # ISSN  N_ENUM  N_CHRON  GOV_DOC UUID
      fields = holding_line.split("\t")

      if fields[3].empty?
        fields[3] = "CH"
      end

      # The old tsv files likely have the old holdings.type (mono|multi|serial)
      case fields[7]
      when "mono"
        fields[7] = "spm"
      when "multi"
        fields[7] = "mpm"
      when "serial"
        fields[7] = "ser"
      when ""
        fields[7] = "mix"
      end

      # The old tsv files likely don't have a uuid
      if fields[12].nil?
        fields[12] = SecureRandom.uuid
      end

      {
        ocn: fields[0].to_i,
        local_id: fields[1],
        organization: fields[2],
        status: fields[3],
        condition: fields[4],
        date_received: DateTime.parse(fields[5]),
        enum_chron: fields[6],
        mono_multi_serial: fields[7],
        issn: fields[8],
        n_enum: fields[9],
        n_chron: fields[10],
        gov_doc_flag: !fields[11].to_i.zero?,
        uuid: fields[12]
      }
    end

    def self.new_from_holding_file_line(line)
      rec = holding_to_record(line.chomp)
      new(rec)
    end

    def self.new_from_scrubbed_file_line(line)
      rec = JSON.parse(line)
      new(rec)
    end

    def self.table
      Services.holdings_table
    end

    # apply order and used paged each -- fetches blocks of rows
    # by doing e.g. select * from holdings where uuid > LAST_UUID order by uuid limit 1000
    def self.paged_each(dataset, &block)
      return to_enum(__method__, dataset) unless block_given?

      dataset.order(:uuid).paged_each(strategy: :filter, &block)
    end

    def self.all
      return to_enum(__method__) unless block_given?

      paged_each(table) do |row|
        yield from_row(row)
      end
    end

    def self.with_ocns(ocns, cluster: nil, organization: nil)
      return to_enum(__method__, ocns, cluster: cluster) unless block_given?

      dataset = table.where(ocn: ocns.to_a.map(&:to_s))

      if organization
        dataset = dataset.where(organization: organization)
      end

      paged_each(dataset) do |row|
        yield from_row(row, cluster: cluster)
      end
    end

    def self.for_organization(organization)
      return to_enum(__method__, organization) unless block_given?

      dataset = table.where(organization: organization)

      paged_each(dataset) do |row|
        yield from_row(row)
      end
    end

    def self.from_row(row, cluster: nil)
      new(row.merge(cluster: cluster))
    end

    def self.batch_add(batch)
      columns = table.columns
      rows = batch.map { |h| columns.map { |c| h.public_send(c) } }
      table.insert_ignore.import(columns, rows)
    end

    def date_received=(date)
      if date.respond_to?(:to_date)
        @date_received = date.to_date
      elsif date.respond_to?(:to_s)
        @date_received = Date.parse(date)
      else
        raise ArgumentError "Can't convert #{date} to date or parse as date"
      end
    end

    def batch_with?(other)
      ocn == other.ocn
    end

    def country_code
      Services.ht_organizations[organization].country_code
    end

    def weight
      Services.ht_organizations[organization].weight
    end

    def save
      self.class.table.insert(to_hash)
    end

    alias_method :save!, :save
  end
end
