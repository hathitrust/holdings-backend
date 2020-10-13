#!/usr/bin/env ruby
# frozen_string_literal: true

TABLENAME = :holdings_htitem_htmember

require "dotenv"
Dotenv.load(".env")

require "pathname"
$LOAD_PATH.unshift(Pathname.new(__dir__).parent + "lib")

require "bundler/setup"
require "logger"
require "services"
require "utils/waypoint"

if ARGV.empty? || ARGV.include?("-h")
  puts "Usage"
  puts "  #{$PROGRAM_NAME} file_to_load <optional_log_file>"
  puts "\n  Default is to log to $stderr"
  exit 1
end

# @return [HoldingsDB] The holdings_db connection
def connection
  Services.holdings_db
end

def get_logger(logfile = $stderr)
  Logger.new(logfile)
end

def validate_database!(connection)
  unless connection.tables.include? TABLENAME
    raise "Table #{TABLENAME} is not present (#{connection.tables.join(", ")})"
  end
end

def validate_inputfile!(filename)
  unless File.exist?(filename)
    raise "File #{filename} not found"
  end
end

filename = Pathname.new(ARGV.shift).realpath
logger = get_logger(ARGV.shift)

validate_database!(connection)
validate_inputfile!(filename)

# Clear it out
connection[TABLENAME].delete

# Load the data
connection.load_tab_delimited_file(filepath: filename, tablename: TABLENAME,
                                   maxlines: 1_000_000, logger: logger)
