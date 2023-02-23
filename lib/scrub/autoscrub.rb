# frozen_string_literal: true

require "services"
require "scrub/member_holding_file"
require "scrub/scrub_output_structure"
require "utils/line_counter"
require "utils/encoding"

module Scrub
  # Usage:
  # Takes a member-submitted holdings file, writes a .ndj file.
  # Programatically:
  # Autoscrub.new(file_path)
  # Commandline:
  # bundle exec ruby lib/autoscrub.rb <file_path_1...n>
  # Location of output and log files determined by ScrubOutputStructure.
  class AutoScrub
    # Won't put in accessors unless we find a solid case for running this
    # by another ruby class.
    attr_reader :output_struct, :out_files, :logger_path, :item_type

    def initialize(path)
      @path = path

      # @member_id and @item_type are used in the path to scrub_logger, but we
      # also need somewhere to log to before we know @member_id and @item_type
      scrub_dir = File.dirname(@path)
      early_scrub_logger_path = File.join(scrub_dir, "scrub.log")
      Services.register(:scrub_logger) do
        Logger.new(early_scrub_logger_path)
      end
      Services.scrub_logger.info("Getting basic info from #{@path}")

      @member_holding_file = Scrub::MemberHoldingFile.new(@path)
      @member_id = @member_holding_file.member_id
      @output_struct = Scrub::ScrubOutputStructure.new(@member_id)
      @item_type = @member_holding_file.item_type_from_filename
      @encoding = Utils::Encoding.new(@path)
      @output_dir = @output_struct.date_subdir!("output")
      @log_dir = @output_struct.date_subdir!("log")
      @out_files = []
      Services.register(:scrub_stats) { {} }

      # Once we have @member_id and @item_type,
      # build a new log path and re-register the service logger to that path
      ymd = Time.new.strftime("%Y%m%d")
      @logger_path = File.join(@log_dir, "#{@member_id}_#{@item_type}_#{ymd}.log")
      Services.logger.info "autoscrub logging to #{@logger_path}"

      Services.register(:scrub_logger) do
        # Get the early log in there.
        FileUtils.mv(early_scrub_logger_path, @logger_path)
        lgr = Logger.new(@logger_path)
        # Show time, file:lineno, level for each log message
        lgr.formatter = proc do |severity, datetime, _progname, msg|
          file_line = caller(4..4).first.split(":")[0, 2].join(":")
          "#{datetime.to_s[0, 19]} | #{file_line} | #{severity} | #{msg}\n"
        end
        lgr
      end

      Services.scrub_logger.info("INIT")
      Services.logger.info("Logging to #{@logger_path}")
    end

    def run
      Services.scrub_logger.info("Started scrubbing #{@path}")

      unless @encoding.ascii_or_utf8?
        Services.scrub_logger.error(
          "Encoding error in #{@path} (unsupported #{@encoding.uchardet})"
        )
        raise EncodingError
      end

      # Figure out batch size for 100 batches.
      line_counter = Utils::LineCounter.new(@path)
      tot_lines = line_counter.count_lines
      if tot_lines <= 1
        raise "File #{@path} has no data? Total lines #{tot_lines}."
      end

      batch_size = tot_lines < 100 ? 100 : tot_lines / 100
      Services.scrub_logger.info("File is #{tot_lines} lines long, batch size #{batch_size}")
      marker = Services.progress_tracker.call(batch_size: batch_size)

      # Set up output file
      datetime = Time.new.strftime("%F-%T").delete(":")
      out_file_path = File.join(
        @output_dir,
        "#{@member_id}_#{@item_type}_#{datetime}.ndj"
      )
      out_file = File.open(out_file_path, "w")
      Services.scrub_logger.info("Outputting to #{out_file_path}")

      @member_holding_file.parse do |holding|
        out_file.puts(holding.to_json)
        marker.incr
        marker.on_batch do |m|
          Services.scrub_logger.info(m.batch_line)
        end
      rescue => e
        Services.scrub_logger.error(e)
        Services.scrub_logger.error(e.backtrace.join("\n"))
      end

      out_file.close
      Services.scrub_logger.info("Finished scrubbing #{@path}")
      FileUtils.mv(out_file_path, @output_struct.member_ready_to_load)
      Services.scrub_logger.info(
        "Output file moved to #{@output_struct.member_ready_to_load.to_path}"
      )
      # Move file and store new location in array.
      @out_files << File.join(
        @output_struct.member_ready_to_load,
        File.split(out_file_path).last
      )
    end
  end
end
