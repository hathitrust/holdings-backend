require "reports/eligible_commitments"

report = Reports::EligibleCommitments.new

puts report.header.join("\t")
report.for_ocns(ARGV.map(&:to_i)) do |row|
  puts row.join("\t")
end
