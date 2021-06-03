# frozen_string_literal: true

def post_to_holdings_channel(msg)
  system("curl -X POST -H 'Content-type: application/json' --data '{\"text\":\"#{msg}\"}' #{ENV['SLACK_URL']}")
end

def review_logs(log_file)
  multiple_ocns_count = 0
  errors = []
  File.open(log_file).each do |line|
    if line =~ /resolves to multiple ocns/
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

concordance_dir = ARGV.shift

raw_gzip_files = Dir.glob("#{concordance_dir}/*txt.gz")

raw_dates = []
raw_dates = raw_gzip_files.map { |fname| fname.split('/').last.split('_').first }.select { |d| d =~ /^\d+$/ }

validated_files = Dir.glob("#{concordance_dir}/*validated.tsv.gz")
validated_dates = validated_files.map { |fname| fname.split('/').last.split('_').first }.select { |d| d =~ /^\d+$/ }

# Validate anything that doesn't have a validated equivalent
dates_to_validate = raw_dates - validated_dates

dates_to_validate.each do |date|
  fin = "#{concordance_dir}/#{date}_concordance.txt.gz"
  fout = "#{concordance_dir}/#{date}_concordance_validated.tsv"
  puts "Validating #{fin}"
  validated = system("bundle exec ruby concordance_validation.rb #{fin} #{fout} > results.tmp")
  post_to_holdings_channel("Validated #{fin}.") if validated
  error_msg = review_logs("#{date}_concordance_validated.tsv.log").join("\n")
  post_to_holdings_channel(error_msg)
  gzipped = system("gzip #{fout}")
end

# If we validated anything, find something to compute the deltas against
if dates_to_validate.any?
  # most recent, previously validated concordance
  prev_conc = validated_files.max
  # most recent concordance we just validated
  new_conc = "#{dates_to_validate.max}_concordance_validated.tsv.gz"

  puts "Diffing #{prev_conc} and #{new_conc}"

  # compute delta
  deltad = system("./get_delta/comm_concordance_delta.sh #{prev_conc} #{new_conc}")

  # move deltas to the concordance_dir
  system("mv data/comm_diff.txt.adds #{concordance_dir}")
  system("mv data/comm_diff.txt.deletes #{concordance_dir}")

  post_to_holdings_channel("Concordance adds and deletes waiting in #{concordance_dir}")
end
