# frozen_string_literal: true

require "reports/eligible_commitments"

# Cmdline input: a list of ocns,
# STDOUT output: a report of which of the input ocns are eligible for commitments.
# Invoke thusly:
# $ bundle exec ruby compile_eligible_commitments_report.rb <list_of_ocns>
# e.g.
# $ bundle exec ruby compile_eligible_commitments_report.rb 1 2 3

if $PROGRAM_NAME == __FILE__
  report = Reports::EligibleCommitments.new
  puts report.header.join("\t")
  report.for_ocns(ARGV.map(&:to_i)) do |row|
    puts row.join("\t")
  end
end
