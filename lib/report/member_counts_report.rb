# frozen_string_literal: true

require_relative "../basic_query_report"
require "data_sources/ht_members"
require "json"

module Report
  MON = "mono"
  MUL = "multi"
  SER = "serial"
  MCR_LABELS  = ["total_loaded", "distinct_ocns", "matching_volumes"].freeze
  MCR_FORMATS = [MON, MUL, SER].freeze

  # Alternate format names used in cost-report freq table.
  ALT_FORMATS = {
    MON => "spm",
    MUL => "mpm",
    SER => "ser"
  }.freeze

  # Runs report queries related to member-submitted holdings
  # and builds a report made out of MemberCountsRows.
  class MemberCountsReport
    attr_accessor :rows

    def initialize(cost_report_freq = nil, members = DataSources::HTMembers.new.members.keys)
      @cost_report_freq = cost_report_freq

      @rows = {}
      # members is just an array of inst_ids, which makes it easy to mock
      # and also enables running a report for a given member or subset of members
      members.sort.each do |org|
        @rows[org] = MemberCountsRow.new(org)
      end
    end

    # Execute queries and populate @rows.
    def run
      populate_rows_with_results(q1, "total_loaded")
      populate_rows_with_results(q2, "distinct_ocns")
      # q3 isnt a query like the previous 2.
      q3 do |org, fmt, count|
        @rows[org].set("matching_volumes", fmt, count)
      end

      self
    end

    private

    # Executes a query and populates the relevant parts of @rows
    def populate_rows_with_results(query, label)
      BasicQueryReport.new.aggregate(query) do |res|
        org = res["_id"]["org"]
        @rows[org].set(label, res["_id"]["fmt"], res["count"])
      end
    end

    # Part 1, count number of loaded holdings records per member & format
    def q1
      [
        { "$match": { "holdings.0": { "$exists": 1 } } },
        { "$project": { "holdings": 1 } },
        { "$unwind": "$holdings" },
        { "$group": {
          "_id":   {
            "org": "$holdings.organization",
            "fmt": "$holdings.mono_multi_serial"
          },
          "count": { "$sum": 1 }
        } },
        { "$sort": { "_id": 1 } }
      ]
    end

    # Part 2, count number of distinct ocns (that are in HT) in holdings per member & format
    def q2
      [
        { "$match": { "holdings.0": { "$exists": 1 }, "ht_items.0": { "$exists": 1 } } },
        { "$project": { "holdings": 1 } },
        { "$unwind": "$holdings" },
        { "$group": {
          "_id": {
            "ocn": "$holdings.ocn",
            "org": "$holdings.organization",
            "fmt": "$holdings.mono_multi_serial"
          }
        } },
        { "$group": { "_id": { "org": "$_id.org", "fmt": "$_id.fmt" }, "count": { "$sum": 1 } } },
        { "$sort": { "_id": 1 } }
      ]
    end

    # Part 3 relies on the freq table having been dumped to a file
    # when last the cost report was run.
    def q3
      unless @cost_report_freq.nil?
        read_freq do |org, data|
          ALT_FORMATS.each do |fmt, alt|
            if data.key?(alt) && @rows.key?(org)
              yield(org, fmt, data[alt].values.sum)
            end
          end
        end
      end
    end

    def read_freq
      File.open(@cost_report_freq) do |freq_file|
        freq_file.each_line do |line|
          # Lines look like:
          # org \t {"ser":{"2":1, ...}, "spm":{"1":1, ...}, "mpm":{"3":2, ...}}
          org, data = line.split("\t")
          yield [org, JSON.parse(data)]
        end
      end
    end
  end

  # Represents one row in the MemberCountsReport, with an org as key and a hash of data.
  class MemberCountsRow

    attr_accessor :counts

    def initialize(org)
      @org    = org
      @counts = {}

      MCR_LABELS.each do |label|
        MCR_FORMATS.each do |fmt|
          @counts[label]    ||= {}
          @counts[label][fmt] = 0
        end
      end
    end

    # 2-row header, like:
    # labels:  < a > < b >
    # formats: x y z x y z
    def self.header
      row1 = ["org"]
      row2 = []
      MCR_LABELS.each do |label|
        row1 << ["<", label, ">"]
        row2 << MCR_FORMATS
      end
      (row1 + ["\n"] + row2).join("\t")
    end

    # Set a value for a given label and format.
    def set(label, fmt, count)
      unless @counts.key?(label)
        raise "bad label #{label}"
      end

      unless @counts[label].key?(fmt)
        raise "bad fmt #{fmt} (#{fmt.class})"
      end

      @counts[label][fmt] = count.to_i
    end

    def to_a
      MCR_LABELS.map do |label|
        MCR_FORMATS.map do |fmt|
          @counts[label][fmt]
        end
      end
    end

    def to_s
      to_a.flatten.join("\t")
    end
  end
end
