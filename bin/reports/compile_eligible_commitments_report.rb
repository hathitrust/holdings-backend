# frozen_string_literal: true

require "reports/eligible_commitments"

if $PROGRAM_NAME == __FILE__
  report = Reports::EligibleCommitments.new
  puts report.header.join("\t")
  report.for_ocns(ARGV.map(&:to_i)) do |row|
    puts row.join("\t")
  end
end
