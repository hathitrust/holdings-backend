# frozen_string_literal: true

require "services"
require "scrub/member_holding_file"
require "scrub/scrub_output_structure"

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
    attr_reader :output_struct

    def initialize(path)
      @path = path

      @member_holding_file = Scrub::MemberHoldingFile.new(@path)
      @member_id = @member_holding_file.member_id
      @output_struct = Scrub::ScrubOutputStructure.new(@member_id)
      @item_type = @member_holding_file.item_type_from_filename
      @output_dir = @output_struct.date_subdir!("output")
      @log_dir = @output_struct.date_subdir!("log")

      # Once we have @member_id and @item_type,
      # build a log path and re-register the service logger to log to that path
      logger_path = File.join(@log_dir, "#{@member_id}_#{@item_type}.log")
      Services.register(:scrub_logger) do
        lgr = Logger.new(logger_path)
        # Show time, file:lineno, level for each log message
        lgr.formatter = proc do |severity, datetime, _progname, msg|
          file_line = caller(4..4).first.split(":")[0, 2].join(":")
          "#{datetime.to_s[0, 19]} | #{file_line} | #{severity} | #{msg}\n"
        end
        lgr
      end

      Services.scrub_logger.info("INIT")
      Services.logger.info("Logging to #{logger_path}")
    end

    def run
      Services.scrub_logger.info("Started scrubbing #{@path}")

      # Figure out batch size for 100 batches.
      tot_lines = count_file_lines
      batch_size = tot_lines < 100 ? 100 : tot_lines / 100
      Services.scrub_logger.info("File is #{tot_lines} lines long, batch size #{batch_size}")
      marker = Services.progress_tracker.new(batch_size)

      # Set up output file
      datetime = Time.new.strftime("%F-%T").delete(":")
      out_file_path = File.join(
        @output_dir,
        "#{@member_id}_#{@item_type}_#{datetime}.ndj"
      )
      out_file = File.open(out_file_path, "w")
      Services.scrub_logger.info("Outputting to #{out_file_path}")

      begin
        @member_holding_file.parse do |holding|
          out_file.puts(holding.to_json)
          marker.incr
          marker.on_batch do |m|
            Services.scrub_logger.info(m.batch_line)
          end
        end
        out_file.close
      rescue => e
        # Any uncaught error that isn't a CustomError should be fatal
        # and is a sign that error handling needs to be improved.
        Services.scrub_logger.fatal(e)
        Services.scrub_logger.fatal(e.backtrace.join("\n"))
        Services.scrub_logger.fatal("Premature exit, exit status 1.")
        exit 1
      end
      Services.scrub_logger.info("Finished scrubbing #{@path}")
      FileUtils.mv(out_file_path, @output_struct.member_ready_to_load)
      Services.scrub_logger.info(
        "Output file moved to #{@output_struct.member_ready_to_load.to_path}"
      )
    end

    private

    def count_file_lines
      # zcat -f works as plain cat if @path is not in gzip format.
      `zcat -f #{@path} | wc -l`.match(/^(\d+)/)[0].to_i
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ARGV.each do |path|
    autoscrub = Scrub::AutoScrub.new(path)
    autoscrub.run
  end
end
