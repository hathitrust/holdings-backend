# frozen_string_literal: true

require_relative "ppnum"

module Utils
  # Naive waypoint class, to keep track of progress over time for long-running
  # processes for which you want to kick out log files with ongoing progress.
  class Waypoint

    attr_reader :batch_seconds, :batch_records, :start_time, :batch_end_time,
                :total_records

    def initialize
      @start_time     = Time.now
      @batch_end_time = @start_time
      @total_records  = 0
      @prev_time      = @start_time
      @prev_count     = 0
      @batch_records  = nil
    end

    # @param [Number] count Number of total/new records processed
    # @param [Boolean] absolute Whether the count of processed records in
    #   `count` is the total overall (default) or relative to the last
    #   time `#mark` was called
    # @return [Void]
    def mark(count, absolute: true)
      @batch_end_time = Time.now
      @batch_records  = if absolute
        count - @prev_count
      else
        count
      end
      @batch_seconds = @batch_end_time - @prev_time

      @prev_time = @batch_end_time

      # Now update for later
      @prev_count    = count
      @total_records += batch_records
    end

    def total_seconds
      @batch_end_time - @start_time
    end

    # @param [Integer] decimals Number of decimal places to the right of the
    # decimal point
    # @return [String] Rate-per-second in form XXX.YY
    def batch_rate_str(decimals = 0)
      return "0" if @total_records.zero?

      format "%5.#{decimals}f", (batch_records.to_f / batch_seconds)
    end

    # @param [Integer] decimals Number of decimal places to the right of the
    # decimal point
    # @return [String] Rate-per-second in form XXX.YY
    def total_rate_str(decimals = 0)
      return "0" if @total_records.zero?

      format "%5.#{decimals}f", (@total_records / total_seconds)
    end

    def seconds_to_time_string(sec)
      hours, leftover = sec.divmod(3600)
      minutes, secs = leftover.divmod(60)
      format("%02dh %02dm %02ds", hours, minutes, secs)
    end

    def batch_line
      # rubocop:disable Layout/LineLength
      "#{ppnum(total_records, 10)}. This batch #{ppnum(batch_records, 5)} in #{ppnum(batch_seconds, 4, 1)}s (#{batch_rate_str} r/s). Overall #{total_rate_str} r/s."
      # rubocop:enable Layout/LineLength
    end

    def final_line
      # rubocop:disable Layout/LineLength
      "Finished. #{ppnum(total_records, 10)} total records in #{seconds_to_time_string(total_seconds)}. Overall #{total_rate_str} r/s."
      # rubocop:enable Layout/LineLength
    end
  end
end
