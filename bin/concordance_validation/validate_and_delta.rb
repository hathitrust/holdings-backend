#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"
require "utils/multi_logger"
require "settings"
require "concordance_validation/delta"

def review_logs(log_file)
  multiple_ocns_count = 0
  errors = []
  File.open(log_file).each do |line|
    if /resolves to multiple ocns/.match?(line)
      multiple_ocns_count += 1
    else
      errors << line
    end
  end
  errors << "#{multiple_ocns_count} resolved to multiple OCNS."
  errors
end

# Check the concordance directory for new concordance files.
# Validate any new files.
# Compute deltas of new concordance with pre-existing validated concordance.

conc_dir = Settings.concordance_path

raw_gzip_files = Dir.glob("#{conc_dir}/raw/*txt.gz").sort

file_names_split = raw_gzip_files.map {|fname| fname.split("/").last.split("_").first }
raw_dates = file_names_split.select {|d| d =~ /^\d+$/ }

validated_files = Dir.glob("#{conc_dir}/validated/*validated.tsv.gz").sort
file_names_split = validated_files.map {|fname| fname.split("/").last.split("_").first }
validated_dates = file_names_split.select {|d| d =~ /^\d+$/ }

# Validate anything that doesn't have a validated equivalent
dates_to_validate = raw_dates - validated_dates

dates_to_validate.each do |date|
  fin = "#{conc_dir}/raw/#{date}_concordance.txt.gz"
  fout = "#{conc_dir}/validated/#{date}_concordance_validated.tsv"
  puts "Validating #{fin}"
  validated = system("bundle exec ruby bin/concordance_validation/validate.rb #{fin} #{fout}" \
                      "> #{conc_dir}/results.tmp")
  Services.logger.info("Validated #{fin}.") if validated
  _gzipped = system("gzip #{fout}")
  error_msg = review_logs("#{conc_dir}/validated/#{date}_concordance_validated.tsv.log").join("\n")
  Services.logger.info(error_msg)
end

# If we validated anything, find something to compute the deltas against
if dates_to_validate.any?
  # most recent, previously validated concordance
  prev_conc = validated_files.max
  # most recent concordance we just validated
  new_conc = "#{dates_to_validate.max}_concordance_validated.tsv.gz"
  new_conc_w_path = "#{conc_dir}/validated/#{new_conc}"

  Services.logger.info("Diffing #{prev_conc} and #{new_conc_w_path}")

  # compute delta
  delta = ConcordanceValidation::Delta.new(File.basename(prev_conc), new_conc)
  delta.run

  Services.logger.info("Concordance adds and deletes waiting in #{conc_dir}/diffs")
end
