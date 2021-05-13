# frozen_string_literal: true

require "pathname"
require "json"

# Sets up a directory structure for storing autoscrub output files:
#
# data/
# - member_data/
# - - x/
# - - - log/
# - - - output/
#
# ... where x is the member_id.
# Subdirs (loaded, log, output, ready_to_load) are generated upon init.
# They can have dated subdirs.
#
# - - - loaded/
# - - - log/
# - - - - 2020-01-01/
# - - - - 2020-02-01/
# - - - output/
# - - - - 2020-01-01/
# - - - - 2020-02-01/
# - - - ready_to_load/
#
# Create dated subdirs for member x (using current date):
#
# sos = ScrubOutputStructure.new("xyz")
#
# sos.date_subdir!("output") # -> Dir
# sos.date_subdir!("log")    # -> Dir
#
# Get latest exising subdir for log or output:
#
# sos.latest("log")    # -> Dir
# sos.latest("output") # -> Dir
class ScrubOutputStructure
  VALID_SUBDIR   = ["log", "output", "ready_to_load", "loaded"].freeze
  VALID_DATE_STR = /^\d\d\d\d-\d\d-\d\d$/.freeze
  DATE_STR       = /\d\d\d\d-\d\d-\d\d/.freeze

  attr_reader :member_id, :member_dir, :member_log, :member_output,
              :member_ready_to_load, :member_loaded

  def initialize(member_id)
    unless member_id.is_a?(String)
      raise ArgumentError, "member_id must be a string"
    end

    @member_id     = member_id
    @member_dir    = mkbase!
    @member_log    = mklog!
    @member_output = mkoutput!
    @member_ready_to_load = mkready_to_load!
    @member_loaded = mkloaded!
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

  def latest(subdir)
    base_dir      = mkdir!(validate_subdir(subdir))
    latest_subdir = base_dir.children.select {|str| str.match?(DATE_STR) }.max

    if latest_subdir.nil?
      nil
    else
      Dir.new(File.join(base_dir, latest_subdir))
    end
  end

  def to_json(*_args)
    dir_hash = {
      "member_id"            => member_id,
      "member_dir"           => member_dir.path,
      "member_log"           => member_log.path,
      "member_output"        => member_output.to_path,
      "member_ready_to_load" => member_ready_to_load.to_path,
      "member_loaded"        => member_loaded.to_path
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
      str
    else
      raise ArgumentError, "invalid subdir name: #{str}"
    end
  end

  # Allows 2020-50-50 and isn't Y100K-proof but hey
  def validate_date_str(str)
    if str.match?(VALID_DATE_STR)
      str
    else
      raise ArgumentError, "invalid date str: #{str}"
    end
  end

  def mkbase!
    mkdir!
  end

  def mklog!
    mkdir!("log")
  end

  def mkoutput!
    mkdir!("output")
  end

  def mkready_to_load!
    mkdir!("ready_to_load")
  end

  def mkloaded!
    mkdir!("loaded")
  end

  def mkdir!(*parts)
    path_parts = [__dir__, "..", "data", "member_data", @member_id] + parts
    pathname   = Pathname.new(File.join(path_parts)).expand_path
    FileUtils.mkdir_p(pathname)

    Dir.new(pathname)
  end

end

if $PROGRAM_NAME == __FILE__
  ARGV.each do |member_id|
    sos = ScrubOutputStructure.new(member_id)
    puts sos.to_json
  end
end
