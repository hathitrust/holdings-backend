# frozen_string_literal: true

require "services"
require "clusterable/base"
require "json"
require "enum_chron"

module Clusterable
  # A holding
  class Holding < Clusterable::Base
    include EnumChron

    attr_accessor :ocn, :local_id, :organization, :n_enum, :n_chron,
      :n_enum_chron, :status, :condition, :gov_doc_flag, :mono_multi_serial,
      :uuid, :issn

    equality_excluded_attr :uuid, :date_received

    attr_reader :date_received, :enum_chron

    def cluster
      Cluster.for_ocns([ocn]).first
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
      {ocn: fields[0].to_i,
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
       uuid: fields[12]}
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

    def self.with_ocns(ocns)
      return to_enum(__method__, ocns) unless block_given?

      dataset = table.where(ocn: ocns.to_a)

      dataset.each do |row|
        yield from_row(row)
      end
    end

    def self.from_row(row)
      new(row)
    end

    def self.batch_add(batch)
      columns = table.columns
      rows = batch.map { |h| columns.map { |c| h.public_send(c) } }
      table.import(columns, rows)
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
