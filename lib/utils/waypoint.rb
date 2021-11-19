# frozen_string_literal: true

require_relative "ppnum"
require "services"

module Utils
  # Naive waypoint class, to keep track of progress over time for long-running
  # processes for which you want to kick out log files with ongoing progress.
  class Waypoint

    attr_accessor :batch_size_target
    attr_reader :last_batch_divsor, :last_batch_seconds, :last_batch_size,
                :start_time, :batch_start_time, :batch_end_time,
                :count, :prev_count

    def initialize(batch_size = 100)
      @batch_size_target = batch_size
      @last_batch_divsor = 0
      @last_batch_size = 0
      @last_batch_seconds = 0

      @start_time = Time.now
      @batch_start_time = @start_time
      @batch_end_time = @start_time

      @count = 0
      @prev_count = 0
    end

    def incr(increase = 1)
      @count += increase
      self
    end

    def on_batch
      if batch_size_exceeded?
        set_waypoint!
        yield self
      end
    end

    def batch_size_exceeded?
      batch_divisor > @last_batch_divsor
    end

    def batch_divisor
      count.div batch_size_target
    end

    def set_waypoint!
      @batch_end_time = Time.now
      @last_batch_size = @count - @prev_count
      @last_batch_seconds = @batch_end_time - @batch_start_time

      reset_for_next_batch!
    end

    def reset_for_next_batch!
      @batch_start_time = batch_end_time
      @prev_count = count
      @last_batch_divsor = batch_divisor
    end

    def total_seconds_so_far
      Time.now - start_time
    end

    def batch_seconds_so_far
      Time.now = batch_start_time
    end

    # @param [Integer] decimals Number of decimal places to the right of the
    # decimal point
    # @return [String] Rate-per-second in form XXX.YY
    def batch_rate_str(decimals = 0)
      return "0" if @count.zero?

      format "%5.#{decimals}f", (last_batch_size.to_f / last_batch_seconds)
    end

    # @param [Integer] decimals Number of decimal places to the right of the
    # decimal point
    # @return [String] Rate-per-second in form XXX.YY
    def total_rate_str(decimals = 0)
      return "0" if @count.zero?

      format "%5.#{decimals}f", (count / total_seconds_so_far)
    end

    def batch_line
      "#{ppnum(count, 10)}. This batch #{ppnum(last_batch_size, 5)} " \
        "in #{ppnum(last_batch_seconds, 4, 1)}s (#{batch_rate_str} r/s). " \
        "Overall #{total_rate_str} r/s."
    end

    def finalize
      "Finished. #{ppnum(count, 10)} total records " \
        " in #{seconds_to_time_string(total_seconds_so_far)}. " \
        "Overall #{total_rate_str} r/s."
    end

    def seconds_to_time_string(sec)
      hours, leftover = sec.divmod(3600)
      minutes, secs = leftover.divmod(60)
      format("%02dh %02dm %02ds", hours, minutes, secs)
    end

  end

end
