# frozen_string_literal: true

# Usage:
# bundle exec ruby bin/reports/compile_member_counts_report.rb <COST_FREQ> <OUTPUT_DIR>

require "reports/member_counts_report"
require "fileutils"

class CompileMemberCounts
  def make_outf(output_dir)
    if output_dir.nil?
      $stdout
    else
      FileUtils.mkdir_p(output_dir)
      ymd = Time.new.strftime("%F")
      File.open(File.join(output_dir, "member_counts_#{ymd}.tsv"), "w")
    end
  end

  def run(*args)
    # Check input.
    cost_report_freq = args.shift
    if cost_report_freq.nil?
      raise "req cost_report_freq file as 1st arg"
    end

    # Set up output
    output_dir = args.shift
    outf = make_outf(output_dir)

    # Run report
    mcr = Reports::MemberCountsReport.new(cost_report_freq).run

    # Write report to output
    outf.puts(Reports::MemberCountsRow.header)
    mcr.rows.each do |org, data|
      outf.puts([org, data].join("\t"))
    end

    outf.close
  end
end

CompileMemberCounts.new.run(ARGV) if $PROGRAM_NAME == __FILE__
