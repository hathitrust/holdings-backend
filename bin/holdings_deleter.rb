# frozen_string_literal: true

require "cluster"
require "date"
require "optparse"
require "optparse/date"
require "services"
require "utils/session_keep_alive"

DEFAULT_KEEPALIVE_TIME = 60

# Deletes holdings and any empty clusters that result.
# Takes criteria and constructs an update_many...pull query based on those criteria.
# Example:
# $ bundle exec ruby bin/delete_matching_holdings.rb <criteria>
# e.g.
# $ bundle exec ruby bin/delete_matching_holdings.rb --organization foo --date_received 2020-01-01
# For full list of criteria, see:
# $ bundle exec ruby bin/delete_matching_holdings.rb --help
class HoldingsDeleter
  attr_reader :matching_criteria

  def initialize(args)
    raise "not implemented"
    @logger = Services.logger
    @matching_criteria = {} # These all go into the query.
    @control_flags     = {} # These control program flow.
    parse_opts(args)        # Set @matching_criteria
    move_opts               # Move selected settings to @control_flags

    if @matching_criteria.empty?
      raise "No matching criteria given."
    end

    if @control_flags[:verbose]
      @logger.info "Criteria:"
      @matching_criteria.each do |k, v|
        @logger.info "\t#{k}:\t#{v} (#{v.class})"
      end
      @logger.info "Control flags:"
      @control_flags.each do |k, v|
        @logger.info "\t#{k}:\t#{v} (#{v.class})"
      end
    end
  end

  def run
    if @control_flags[:noop]
      @logger.info "noop!" if @control_flags[:verbose]
      return nil
    end

    result = nil
    keepalive_time = @control_flags[:session_keepalive_time] || DEFAULT_KEEPALIVE_TIME
    Utils::SessionKeepAlive.new(keepalive_time).run do
      # Construct query.
      pull_query = { "$pull": { "holdings": { "$and": [@matching_criteria] } } }
      @logger.info "Pull-query: #{pull_query}" if @control_flags[:verbose]

      # Execute query/ies.
      result = Cluster.collection.update_many({}, pull_query)
      unless @control_flags[:leave_empties]
        @logger.info "Deleting empty clusters" if @control_flags[:verbose]
        delete_empty_clusters
      end

      # result is a Mongo::Operation::Update::Result obj and can be inspected further.
      @logger.info "Result: #{result.inspect}" if @control_flags[:verbose]
    end

    result
  end

  # This should perhaps be a method on Cluster, in some form?
  # Or broken out into its own little bin script?
  def delete_empty_clusters
    query = {
      "$and": [
        { "ht_items.0":        { "$exists": 0 } },
        { "holdings.0":        { "$exists": 0 } },
        { "commitments.0":     { "$exists": 0 } },
        { "ocn_resolutions.0": { "$exists": 0 } }
      ]
    }

    Cluster.where(query).no_timeout.each(&:delete)
  end

  private

  def parse_opts(args)
    @parser = OptionParser.new do |opts|
      opts.on("--condition STR (BRT)", String) do |cond|
        opt_regex(:condition, cond, /^(BRT)?$/)
      end
      opts.on("--country_code STR (us/ca/uk etc)", String) do |country|
        opt_regex(:country_code, country, /^([a-z][a-z])$/)
      end
      opts.on("--date_received YYYY-MM-DD", Date)
      opts.on("--enum_chron STR", String)
      opts.on("--gov_doc_flag BOOL (true/false)", String) do |gdf|
        @matching_criteria[:gov_doc_flag] = (gdf == "true")
      end
      opts.on("--issn STR", String)
      opts.on("--leave_empties")
      opts.on("--local_id STR", String)
      opts.on("--mono_multi_serial STR (mix/mon/spm/mpm/ser)", String) do |mms|
        opt_regex(:mono_multi_serial, mms, /^(mix|mon|spm|mpm|ser)$/)
      end
      opts.on("--n_chron STR", String)
      opts.on("--n_enum STR", String)
      opts.on("--noop")
      opts.on("--ocn INT", Integer)
      opts.on("--organization STR", String)
      opts.on("--session_keepalive_time INT (s)", Integer)
      opts.on("--status STR (CH/LM/WD)", String) do |status|
        opt_regex(:status, status, /^(CH|LM|WD)$/)
      end
      opts.on("--uuid STR", String)
      opts.on("--verbose")
      opts.on("--weight FLOAT", Float)
      opts.on("--help", "Prints this help") do
        puts opts
        exit
      end
    end.parse!(args, into: @matching_criteria)
  end

  # When an option must match a regex.
  def opt_regex(opt, val, regex)
    unless val.match?(regex)
      raise "--#{opt} value '#{val}' must match #{regex}"
    end

    @matching_criteria[opt] = val
  end

  def move_opts
    # Move any control values over from @matching_criteria to @control_flags
    control_commands = [
      :leave_empties,
      :noop,
      :session_keepalive_time,
      :verbose
    ]

    control_commands.each do |cmd|
      if @matching_criteria.key?(cmd)
        @control_flags[cmd] = @matching_criteria.delete(cmd)
      end
    end
  end

end

if __FILE__ == $PROGRAM_NAME
  HoldingsDeleter.new(ARGV).run
end
