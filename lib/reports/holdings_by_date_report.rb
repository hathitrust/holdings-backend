require "basic_query_report"
require "services"
Services.mongo!

# When HT staff wants to know which members haven't submitted holdings
# (that were subsequently successfully loaded) in a while. Breaks holdings
# down by organization and mono_multi_serial
# Example:
#   require "reports/holdings_by_date_report"
#   rpt = Reports::HoldingsByDateReport.new
#   rpt.run
#   puts "wrote to #{rpt.outf}"

module Reports
  class HoldingsByDateReport
    # For each group (holding org+fmt), get the max date_received
    def query
      [
        {"$match": {"holdings.0": {"$exists": 1}}},
        {"$project": {holdings: 1}},
        {"$unwind": "$holdings"},
        {
          "$group": {
            _id: {
              org: "$holdings.organization",
              fmt: "$holdings.mono_multi_serial"
            },
            max_date: {"$max": "$holdings.date_received"}
          }
        },
        {"$sort": {_id: 1}}
      ]
    end

    # Full report to file.
    def run
      File.open(outf, "w") do |f|
        f.puts header
        data do |res|
          f.puts to_row(res)
        end
      end
    end

    # Get full path for writing
    def outf
      dir = Settings.holdings_by_date_report_path || "/tmp"
      FileUtils.mkdir_p(dir)
      ymd = Time.now.strftime("%Y%m%d")
      fname = "holdings_by_date_report_#{ymd}.tsv"
      File.join(dir, fname)
    end

    # Header string for output
    def header
      ["organization", "format", "max_load_date"].join("\t")
    end

    # enumerator for results
    def data
      return enum_for(:data) unless block_given?
      BasicQueryReport.new.aggregate(query) do |res|
        yield res
      end
    end

    # result formatter for output
    def to_row(res)
      org = res["_id"]["org"]
      fmt = res["_id"]["fmt"]
      max_date = res["max_date"].strftime("%Y")

      [org, fmt, max_date].join("\t")
    end
  end
end
