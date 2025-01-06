require "cluster"
require "services"

# Goes through all clusters, checks if they are valid,
# and prints the first ocn of any invalid cluster to a file.

class ClusterValidator
  attr_reader :output_path # file name
  def initialize
    # Make an output file in the right place
    ymd = Time.now.strftime("%Y-%m-%d")
    dir = Settings.local_report_path
    FileUtils.mkdir_p(dir)
    @output_path = "#{dir}/cluster_validator_#{ymd}.txt"
  end

  def run
    puts "Writing to #{output_path}"
    File.open(output_path, "w") do |outf|
      # need to load the entire cluster to validate subdocuments from
      # previously-persisted documents
      # https://jira.mongodb.org/browse/MONGOID-5704
      outf.puts "# These are ocns of invalid clusters:"
      Cluster.each do |c|
        # force loading all embedded documents for re-validation
        c.as_document
        unless c.valid?
          outf.puts(c.ocns.first)
        end
      end
      outf.puts "# Done"
    end
  end
end

if __FILE__ == $0
  ClusterValidator.new.run
end
