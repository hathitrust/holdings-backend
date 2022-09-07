# frozen_string_literal: true

require_relative "../basic_query_report"
require "data_sources/ht_organizations"
require "json"

module Reports
  MON = "mono"
  MUL = "multi"
  SER = "serial"
  MCR_LABELS = [
    "total_loaded",
    "matching_volumes"
  ].freeze
  MCR_FORMATS = [MON, MUL, SER].freeze

  # Alternate format names used in cost-report freq table.
  ALT_FORMATS = {
    MON => "spm",
    MUL => "mpm",
    SER => "ser"
  }.freeze

  # Runs report queries related to member-submitted holdings
  # and builds a report made out of MemberCountsRows.
  class MemberCounts
    def initialize(cost_report_freq = nil, output_dir = nil, members = Services.ht_organizations.members.keys)
      @cost_report_freq = cost_report_freq
      @output_dir = output_dir

      @rows = {}
      # members is just an array of inst_ids, which makes it easy to mock
      # and also enables running a report for a given member or subset of members
      members.sort.each do |org|
        @rows[org] = MemberCountsRow.new(org)
      end
    end

    def rows
      unless @rows_loaded
        total_loaded
        matching_volumes
      end
      @rows
    end

    def run(output_filename = report_file(@output_dir))
      total_loaded
      matching_volumes

      File.open(output_filename, "w") do |fh|
        fh.puts(Reports::MemberCountsRow.header)
        rows.each do |org, data|
          fh.puts([org, data].join("\t"))
        end

        fh.close
      end
    end

    private

    # Count number of loaded holdings records per member & format
    def total_loaded
      q = [
        {"$match": {"holdings.0": {"$exists": 1}}},
        {"$project": {holdings: 1}},
        {"$unwind": "$holdings"},
        {"$group": {
          _id: {
            org: "$holdings.organization",
            fmt: "$holdings.mono_multi_serial"
          },
          count: {"$sum": 1}
        }}
      ]

      BasicQueryReport.new.aggregate(q) do |res|
        org = res["_id"]["org"]
        fmt = res["_id"]["fmt"]
        @rows[org].total_loaded[fmt] = res["count"]
      end
    end

    # This part relies on the freq table having been dumped to a file
    # when last the cost report was run.
    def matching_volumes
      unless @cost_report_freq.nil?
        read_freq do |org, data|
          ALT_FORMATS.each do |fmt, alt|
            if data.key?(alt) && @rows.key?(org)
              @rows[org].matching_volumes[fmt] = data[alt].values.sum
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

    def report_file(output_dir)
      if output_dir.nil?
        $stdout
      else
        FileUtils.mkdir_p(output_dir)
        ymd = Time.new.strftime("%F")
        File.join(output_dir, "member_counts_#{ymd}.tsv")
      end
    end
  end

  # Represents one row in the MemberCountsReport, with an org as key and a hash of data.
  class MemberCountsRow
    attr_accessor :total_loaded, :matching_volumes

    def initialize(org)
      @org = org
      @total_loaded = {MON => 0, MUL => 0, SER => 0}
      @matching_volumes = {MON => 0, MUL => 0, SER => 0}
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

    def to_a
      [
        @total_loaded.values,
        @matching_volumes.values
      ].flatten
    end

    def to_s
      to_a.join("\t")
    end
  end
end
