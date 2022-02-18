# frozen_string_literal: true

require "reports/uncommitted_holdings"
require "optparse"
require "services"

Services.mongo!

def main(args)
  criteria = parse_opts(args)
  report = Reports::UncommittedHoldings.new(**criteria)
  puts report.header.join("\t")
  report.run do |record|
    puts record.to_s
  end
end

def parse_opts(args)
  criteria = {}
  help_str = "Restrict search to clusters matching"
  OptionParser.new do |opts|
    opts.on("--ocn [INT]", Array, "#{help_str} OCN(s)") do |ocns|
      ocns.map!(&:to_i)
    end
    opts.on("--organization [STR]", Array, "#{help_str} org(s)")
    opts.on("--all", "Search across all clusters.")
    opts.on("--verbose")
    opts.on("--noop")
    opts.on("--help", "You're looking at it.") do |help|
      puts opts
      exit
    end
  end.parse!(args, into: criteria)

  criteria
end

main(ARGV) if __FILE__ == $PROGRAM_NAME
