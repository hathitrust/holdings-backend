# frozen_string_literal: true

require "reports/commitment_replacements"

# Cmdline input: a list of ocns,
# STDOUT output: a report of which of the input ocns are eligible for commitments.
# Invoke thusly:
# $ bundle exec ruby bin/compile_commitments_replacements_report.rb <list_of_ocns>
# e.g.
# $ bundle exec ruby bin/compile_commitments_replacements_report.rb 1 2 3

if $PROGRAM_NAME == __FILE__
  report = Reports::CommitmentReplacements.new
  puts report.header.join("\t")
  report.for_ocns(ARGV.map(&:to_i)) do |row|
    puts row.join("\t")
  end
end
