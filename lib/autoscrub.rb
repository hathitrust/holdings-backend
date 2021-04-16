# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "member_holding_file"
require "scrub_output_structure"
require "logger"
require "services"

=begin Usage:

Takes a member-submitted holdings file, writes a .ndj file.

Programatically:
Autoscrub.new(file_path)

Commandline:
bundle exec ruby lib/autoscrub.rb <file_path_1...n>

Location of output and log files determined by ScrubOutputStructure. 

=end

class AutoScrub
  def initialize(path)
    @path = path

    @member_holding_file = MemberHoldingFile.new(@path)
    @member_id           = @member_holding_file.member_id    
    @output_struct       = ScrubOutputStructure.new(@member_id)
    @item_type           = @member_holding_file.get_item_type_from_filename()
    @output_dir          = @output_struct.date_subdir!("output")
    @log_dir             = @output_struct.date_subdir!("log")

    logger_path = File.join(@log_dir, "#{@member_id}_#{@item_type}.log")
    Services.logger.info("Logging to #{logger_path}")
    @logger = Logger.new(logger_path)
  end

  def run
    @logger.info("Started scrubbing #{@path}")
    begin
      out_file_path = File.join(@output_dir, "#{@member_id}_#{@item_type}.ndj")
      out_file      = File.open(out_file_path, "w")
      @logger.info("Outputting to #{out_file_path}")
      @member_holding_file.parse do |holding|
        out_file.puts(holding.to_json)
      end
      out_file.close()
    rescue StandardError => err
      @logger.error(err)
    end
    @logger.info("Finished scrubbing #{@path}")
  end

end

if $PROGRAM_NAME == __FILE__
  ARGV.each do |path|
    autoscrub = AutoScrub.new(path)
    autoscrub.run()
  end
end
