require "frequency_table"
require "reports/cost_report"

frequency_tables = ARGV.map { |file| FrequencyTable.new(data: File.read(file)) }

summed_frequency_table = frequency_tables.reduce(:+)

report = Reports::CostReport.new(target_cost: Settings.target_cost || ENV["TARGET_COST"],
  precomputed_frequency_table: summed_frequency_table)

report.run
