# frozen_string_literal: true

=begin

Sets up a directory structure for storing autoscrub output files:

data/
- member_data/
- - x/
- - - log/
- - - output/

Where log and output are generated upon init.
They can have dated subdirs.

- - - log/
- - - - 2020-01-01/
- - - - 2020-02-01/
- - - output/
- - - - 2020-01-01/
- - - - 2020-02-01/

Create dated subdirs for member x (using current date):

sos = ScrubOutputStructure.new("xyz")

sos.date_subdir!("output") # -> Dir
sos.date_subdir!("log")    # -> Dir

Get latest exising subdir for log or output:

sos.latest("log")    # -> Dir
sos.latest("output") # -> Dir

=end

require "pathname"
require "json"

class ScrubOutputStructure

  VALID_SUBDIR   = ["log", "output"]
  VALID_DATE_STR = /^\d\d\d\d-\d\d-\d\d$/
  
  attr_reader :member_id, :member_dir, :member_log, :member_output

  def initialize(member_id)
    unless member_id.is_a?(String)
      raise "member_id must be a string"
    end

    @member_id     = member_id
    @member_dir    = mkbase!
    @member_log    = mklog!
    @member_output = mkoutput!
  end

  # A call like:
  # ScrubOutputStructure.new("xyz").date_subdir!("log")
  # ... on 2020-12-30 makes the dir
  # /usr/src/app/data/member_data/xyz/log/2020-12-30/
  def date_subdir!(subdir, date_str = Time.new.strftime("%F"))
    mkdir!(
      validate_subdir(subdir),
      validate_date_str(date_str)
    )
  end

  # Remove the dir that belongs to @member_id and everything under it.
  def remove_recursive!
    FileUtils.remove_dir(member_dir.path)
    true
  end

  def latest(subdir)
    base_dir      = mkdir!(validate_subdir(subdir))
    latest_subdir = base_dir.children.select{ |str|
      str =~ /\d\d\d\d-\d\d-\d\d/
    }.sort.last

    return latest_subdir.nil? ?
             nil : Dir.new(File.join(base_dir, latest_subdir))
  end
  
  def to_json
    dir_hash = {
      "member_id"     => member_id,
      "member_dir"    => member_dir.path,
      "member_log"    => member_log.path,
      "member_output" => member_output.to_path,
    }

    unless latest("output").nil?
      dir_hash["latest_output"] = latest("output").to_path
    end

    JSON.generate(dir_hash)
  end

  # private private private private private private private 
  private

  def validate_subdir(str)
    if VALID_SUBDIR.include?(str)
      return str
    else
      raise "invalid subdir name: #{str}"
    end
  end

  # Allows 2020-50-50 and isn't Y100K-proof but hey
  def validate_date_str(str)
    if str =~ VALID_DATE_STR
      return str
    else
      raise "invalid date str: #{str}"
    end
  end
  
  def mkbase!
    mkdir!()
  end

  def mklog!
    mkdir!("log")
  end

  def mkoutput!
    mkdir!("output")
  end
  
  def mkdir!(*parts)
    path_parts = [__dir__, "..", "data", "member_data", @member_id] + parts
    pathname   = Pathname.new(File.join(path_parts)).expand_path
    FileUtils.mkdir_p(pathname)

    return Dir.new(pathname)
  end
  
end

if $PROGRAM_NAME == __FILE__
  ARGV.each do |member_id|
    sos = ScrubOutputStructure.new(member_id)
    puts sos.to_json
  end
end
