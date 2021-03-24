# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "member_holding_file"

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
  end

  def run
    member_holding_file = MemberHoldingFile.new(@path)
    member_id = member_holding_file.member_id
    member_holding_file.parse do |holding|
      puts holding.to_json
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ARGV.each do |path|
    autoscrub = AutoScrub.new(path)
    autoscrub.run()
  end
end
