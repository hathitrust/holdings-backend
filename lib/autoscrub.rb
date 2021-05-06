# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "services"
require "custom_errors"
require "member_holding_file"
require "scrub_output_structure"
require "utils/waypoint"

=begin Usage:

Takes a member-submitted holdings file, writes a .ndj file.

Programatically:
Autoscrub.new(file_path)

Commandline:
bundle exec ruby lib/autoscrub.rb <file_path_1...n>

Location of output and log files determined by ScrubOutputStructure.

=end

class AutoScrub

  # Won't put in accessors unless we find a solid case for running this
  # by another ruby class.

  def initialize(path)
    @path = path
        
    @member_holding_file = MemberHoldingFile.new(@path)
    @member_id           = @member_holding_file.member_id
    @output_struct       = ScrubOutputStructure.new(@member_id)
    @item_type           = @member_holding_file.get_item_type_from_filename()
    @output_dir          = @output_struct.date_subdir!("output")
    @log_dir             = @output_struct.date_subdir!("log")

    # Once we have @member_id and @item_type,
    # build a log path and re-register the service logger to log to that path
    logger_path = File.join(@log_dir, "#{@member_id}_#{@item_type}.log")    
    Services.register(:scrub_logger) {
      lgr = Logger.new(logger_path)
      # Show time, file:lineno, level for each log message
      lgr.formatter    = proc do |severity, datetime, progname, msg|
        fileLine       = caller(0)[4].split(':')[0,2].join(':')
        "#{datetime.to_s[0,19]} | #{fileLine} | #{severity} | #{msg}\n"
      end
      lgr
    }
    
    Services.scrub_logger.info("INIT")
    Services.logger.info("Logging to #{logger_path}")
  end

  def run
    Services.scrub_logger.info("Started scrubbing #{@path}")

    # We're committed to running on a *nix machine anyways, right?
    tot_lines  = `wc -l #{@path}`.match(/^(\d+)/)[0].to_i
    batch_size = tot_lines < 100 ? 100 : tot_lines / 100
    waypoint   = Utils::Waypoint.new(batch_size)
    datetime   = Time.new.strftime("%F-%T").gsub(":", "")
    
    out_file_path = File.join(
      @output_dir,
      "#{@member_id}_#{@item_type}_#{datetime}.ndj"
    )
    out_file = File.open(out_file_path, "w")
    Services.scrub_logger.info("Outputting to #{out_file_path}")
    begin
      @member_holding_file.parse do |holding|
        out_file.puts(holding.to_json)                  
        waypoint.incr
        waypoint.on_batch do |wp|
          Services.scrub_logger.info(wp.batch_line)
        end
      end
      out_file.close()
    rescue StandardError => err
      # Any uncaught error that isn't a CustomError should be fatal
      # and is a sign that error handling needs to be improved.
      Services.scrub_logger.fatal(err)
      Services.scrub_logger.info("Premature exit, exit status 1.")
      exit 1
    end
    Services.scrub_logger.info("Finished scrubbing #{@path}")
  end

end

if $PROGRAM_NAME == __FILE__
  ARGV.each do |path|
    autoscrub = AutoScrub.new(path)
    autoscrub.run()
  end
end
