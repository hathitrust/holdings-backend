# frozen_string_literal: true

require "date"
require "mongo_updater"

# This is an outer wrapper for a MongoUpdater call.
# Objective: based on commitments.committed_date, set commitments.phase.
# Usage: bundle exec ruby get_by_date.rb <date_str> <phase>
# E.g. : bundle exec ruby get_by_date.rb "2023-01-31 00:00:00 UTC" 3
module SharedPrint
  class PhaseUpdater
    def initialize(date, phase)
      # Get input
      @date = date
      @phase = phase

      validate!
      puts "Get commitments with committed_date #{@date}."
      puts "Set phase to #{@phase}."
    end

    # Make sure date and phase look like they should.
    def validate!
      date_rx = /^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s[A-Z]{3}$/
      raise ArgumentError, "bad date: #{@date}" unless date_rx.match?(@date)

      @phase = @phase.to_i
      raise ArgumentError, "bad phase: #{@phase}" unless [0, 1, 2, 3].include?(@phase)
    rescue ArgumentError => e
      puts "ERROR: Failed validation: #{e.message}"
      exit
    end

    # Pass on call to MongoUpdater which does all the lifting.
    def run
      puts "Started: #{Time.now.utc}"
      res = MongoUpdater.update_embedded(
        clusterable: "commitments",
        matcher: {committed_date: DateTime.parse(@date)},
        updater: {phase: @phase}
      )
      puts res.inspect
      puts "Finished: #{Time.now.utc}"
    end
  end
end

if $0 == __FILE__
  date = ARGV.shift
  phase = ARGV.shift
  SharedPrint::PhaseUpdater.new(date, phase).run
end
