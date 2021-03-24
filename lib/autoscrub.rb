# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "member_holding_file"
require "scrub_output_structure"

=begin Usage:

Takes a member-submitted holdings file, writes a .ndj file.

Programatically:
Autoscrub.new(file_path)

Commandline:
bundle exec ruby lib/autoscrub.rb <file_path_1...n>

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
  end

  def run
    out_file_path = File.join(@output_dir, "#{@member_id}_#{@item_type}.ndj")
    out_file      = File.open(out_file_path, "w")
    @member_holding_file.parse do |holding|
      out_file.puts(holding.to_json)
    end
    out_file.close()
  end

end

if $PROGRAM_NAME == __FILE__
  ARGV.each do |path|
    autoscrub = AutoScrub.new(path)
    autoscrub.run()
  end
end
