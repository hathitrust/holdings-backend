# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require "zlib"
require "services"
require "json"
require "securerandom"
require_relative "scrub_fields"

class FileNameError < StandardError
end

class WellFormedFileError < StandardError
end

class WellFormedHeaderError < StandardError
end

class MemberIdError < StandardError
end

class ColValError < StandardError
end

#
# "Scrubs", as in validates and extracts, member-submitted holdings files.
# Takes a member_id and a number of file paths:
#
# as = Autoscrub.new("xyz", "path/to/fi.tsv", ..., "path/to/fj.tsv")
# as.scrub_files()
#
# It should write one session log for the entire session,
# one log per input file
# and one output .ndj per input file
#
class Autoscrub
  # Todo: read these dir paths from config/env?
  DATA_DIR = "#{__dir__}/../data/new"
  LOG_DIR  = "#{__dir__}/../testdata"

  SPEC_REGEXP = {
    # A single regex for file name pass/fail.
    FILENAME:            /^
    [a-z\-]+              # member_id
    _(mono|multi|serial)  # item_type
    _(full|partial)       # update_type
    _\d{8}                # date_str (loosest possible YYYYMMDD check)
    (_.+)?                # optional "rest" part
    .tsv                  # must have a .tsv extension
    (.gz)?                # may have a .gz extension
    $/x.freeze,

    # Split filename on these to get the individual parts.
    FILENAME_PART_DELIM: /[_.]/.freeze,

    # If filename fail, further regexes to discover why.
    MEMBER_ID:           /^[a-z_\-]+$/.freeze,
    ITEM_TYPE:           /^(mono|multi|serial)$/.freeze,
    ITEM_TYPE_CONTEXT:   /_(mono|multi|serial)_/.freeze,
    UPDATE_TYPE:         /^(full|partial)$/.freeze,

    # A YYYYMMDD date string is expected,
    # and of course this regex is overly permissive
    # but let's leave it like that.
    DATE:                /^\d{8}$/.freeze
  }.freeze

  # Required header columns for all files
  REQ_HEADER_COLS = ["oclc", "local_id"].freeze

  # Optional header columns per item_type
  OPT_HEADER_COLS = {
    "mono"   => ["status", "condition", "govdoc"],
    "multi"  => ["status", "condition", "govdoc", "enumchron"],
    "serial" => ["govdoc", "issn"]
  }.freeze
  # Max number of optional cols:
  MAX_OPT_COLS = OPT_HEADER_COLS.max_by {|_k, v| v.length }.last.size

  MIN_FILE_COLS = REQ_HEADER_COLS.size
  MAX_FILE_COLS = MIN_FILE_COLS + MAX_OPT_COLS

  # Give a member_id and a list of files.
  def initialize(member_id, *files)
    # Check that member_id is valid
    unless valid_member_id?(member_id)
      raise MemberIdError, "Bad member_id #{member_id}"
    end

    @member_id  = member_id
    @files      = files
    @out_file   = nil
    @log_file   = nil
    date        = Time.now.strftime("%Y%m%d")
    session_log_name = "session_#{@member_id}_#{date}"
    @session_log = get_log_file(session_log_name)
    slog("Starting session log for member #{@member_id}")
    Services.logger.warn "Logging to #{File.expand_path(@session_log.path)}"

    @scrubfields = ScrubFields.new

    slog("Received #{@files.size} file(s)")
    @files.each do |f|
      slog(f)
    end
  end

  # DRY code for output, log, slog
  # Writes to handle if you can, otherwise to stdout
  def p_file_or_stderr(handle, str, clean=false)
    time        = Time.new.strftime("%Y-%m-%d %H:%M:%S")
    caller_loc  = caller_locations[1]
    caller_meth = caller_loc.label
    log_prefix  = "#{time} | .#{caller_meth} |"

    msg = clean ? str : "#{log_prefix} #{str}"
    
    if handle.nil?
      Services.logger.info msg
    else
      handle.puts msg
    end
  end

  # Writes string to @out_file, if defined, else to STDOUT.
  def output(str)
    p_file_or_stderr(@out_file, str, true)
  end

  # Writes string to @log_file, if defined, else to STDERR.
  # TODO: real logger
  def log(str)
    p_file_or_stderr(@log_file, str)
  end

  # Writes string to @session_log, if defined, else to STDERR.
  # TODO: real logger
  def slog(str)
    p_file_or_stderr(@session_log, str)
  end

  def scrub_file(f)
    # TODO: extract a single-file scrubber to a separate class
    unless valid_filename?(File.basename(f))
      raise FileNameError.new "Invalid file name"
    end

    @out_file = get_out_file(f)
    @log_file = get_log_file(f)
    log("Starting scrub log of #{f} for #{@member_id}")
    @scrubfields.logger = @log_file
    raise WellFormedFileError unless well_formed_file?(f)
  end

  # Goes through the files given to initialize
  # Returns a hash of {f1=>BOOL, ..., fn=>BOOL}
  # where key=file and BOOL=success.
  def scrub_files
    file_success = {}
    @files.each do |f|
      slog("Scrubbing #{f}")
      begin
        scrub_file(f)
        file_success[f] = true
      rescue StandardError => e
        slog("Input file #{f} rejected, reason: #{e} #{e.message}")
        file_success[f] = false
      rescue SystemCallError => e
        slog("something wrong with file #{f}?")
        file_success[f] = false
      ensure
        log("File stats:\n#{@scrubfields.stats_to_str}")
        @scrubfields.clear_stats
        @out_file.close if @out_file.methods.include?(:close)
        @out_file = nil
        @log_file.close if @log_file.methods.include?(:close)
        @log_file = nil
      end
    end
    file_success
  end

  # Check that the member_id points to a member in the data store
  def valid_member_id?(member_id)
    # TODO: Tie in data store wrapper that checks for valid members
    # Currently all values will be accepted except "failme"
    log("valid_member_id? not fully implemented, allows anything")
    log("Checking member_id #{member_id}")
    ret = case member_id
    when nil
      false
    when "failme"
      false
    when SPEC_REGEXP[:MEMBER_ID]
      true
        else
      false
    end
    log("member_id #{member_id} OK? #{ret}")
    ret
  end

  # Check that a filename conforms to spec.
  def valid_filename?(filename)
    # If it matches, perfect, we don't need to analyze or report.
    if filename.start_with?(@member_id) &&
        SPEC_REGEXP[:FILENAME].match?(filename)
      return true
    end

    # If we made it here, the match failed, so break it down & return false.
    (member_id, item_type, update_type, date_str, *rest) =
      filename.split(SPEC_REGEXP[:FILENAME_PART_DELIM])

    # slog because @log is not open when this is called
    slog([
      "Processing of #{filename} failed due to filename errors.",
      "Filename must match the template:",
      "<member_id>_<item_type>_<update_type>_<date_str>_<rest>",
      "Filename was analyzed as:",
      "member_id\t\"#{member_id}\"\t#{analyze_member_id(member_id)}",
      "member_id\t\"#{member_id}\"\t#{file_belong_to_member(member_id)}",
      "item_type\t\"#{item_type}\"\t#{analyze_item_type(item_type)}",
      "update_type\t\"#{update_type}\"\t#{analyze_update_type(update_type)}",
      "date_str\t\"#{date_str}\"\t#{analyze_date_str(date_str)}",
      "rest\t\"#{rest.join(" ")}\"\t#{analyze_rest(rest)}"
    ].join("\n"))

    false
  end

  def analyze_member_id(str)
    not_nil_and_match(
      str,
      SPEC_REGEXP[:MEMBER_ID],
      "must be all a-z+"
    )
  end

  def file_belong_to_member(member_id)
    not_nil_and_match(
      member_id,
      /^#{@member_id}$/,
      "must match @member_id (#{@member_id})"
    )
  end

  def analyze_item_type(str)
    not_nil_and_match(
      str,
      SPEC_REGEXP[:ITEM_TYPE],
      "must be mono|multi|serial"
    )
  end

  def analyze_update_type(str)
    not_nil_and_match(
      str,
      SPEC_REGEXP[:UPDATE_TYPE],
      "must be full|partial"
    )
  end

  def analyze_date_str(str)
    not_nil_and_match(
      str,
      SPEC_REGEXP[:DATE],
      "must be 8 digits"
    )
  end

  # Shortcut for the analyze_x methods above.
  # Checks that str is not nil, and matches regexp
  # otherwise issues a warning.
  def not_nil_and_match(str, regexp, warning)
    if str.nil?
      "must not be empty, and #{warning}"
    elsif regexp.match?(str)
      "ok"
    else
      "not ok: #{warning}"
    end
  end

  # We allow the 'rest' to contain arbitrary labels, it just has to end
  # with our required file extension(s).
  def analyze_rest(arr)
    return "must not be empty" if arr.empty?

    # magic numbers abound
    if arr.size > 10 || arr.join.length > 100
      return "not ok, too long"
    end

    if arr[-1] == "tsv" || (arr[-2] == "tsv" && arr[-1] == "gz")
      return "ok"
    end

    "not ok, must end in .tsv or .tsv.gz"
  end

  # Opens a new outfile in DATA_DIR with a name based on the infile
  def get_out_file(filename)
    out_filename = filename.gsub(/^.+\//, "").gsub(/\.gz$/, "")
    out_filename.concat(".out.ndj")
    slog("Opening output file #{DATA_DIR}/#{out_filename}")
    File.open("#{DATA_DIR}/#{out_filename}", "w")
  end

  # Opens a new logfile in LOG_DIR with a name based on the infile
  def get_log_file(filename)
    log_filename = filename.gsub(/^.+\//, "").gsub("\.gz", "").gsub("\.tsv", "")
    today = Time.now.strftime("%Y%m%d")
    log_filename.concat("_#{today}.log.txt")
    slog("Opening log file #{LOG_DIR}/#{log_filename}")
    File.open("#{LOG_DIR}/#{log_filename}", "w")
  end

  # Opens a text file (optionally zipped) and yields one chomped
  # line at a time (together with line number)
  # That's right, chomp not strip, since we care about empty cols too.
  def read_file(filename)
    line_no = 0

    # Any filename or relative path will be relative to DATA_DIR
    # but absolute paths are absolute.
    file_path = "#{DATA_DIR}/#{filename}"
    if filename.include?("/")
      file_path = filename
    end

    (filename.end_with?(".gz") ? Zlib::GzipReader : File)
      .open(file_path).each_line do |line|
        line_no += 1
        line.chomp!
        yield line, line_no
      end
  end

  # Given filename, determine mono|multi|serial.
  # Returns empty string as failure.
  def get_item_type(filename)
    item_type = ""
    if SPEC_REGEXP[:ITEM_TYPE_CONTEXT].match(filename)
      item_type = Regexp.last_match(1)
    else
      log("Did not find item_type in filename")
    end
    item_type
  end

  # Check that a file has a header line, consistent number
  # of cols, lines that are not too long.
  def well_formed_file?(filename)
    # mono|multi|serial
    item_type = get_item_type(filename)
    # Stores which col is where, based on header line.
    col_map = {}

    read_file(filename) do |line, line_no|
      cols = line.split("\t")
      # Header line:
      # Get col_map if valid
      # use col map in checking the rest of the lines
      if line_no == 1
        unless well_formed_header?(cols, item_type)
          log("File rejected: header not OK.")
          return false
        end
        # header was ok, set col_map
        log("Header OK.")
        col_map = get_col_map(cols, item_type)
      else
        # All other lines:
        unless well_formed_line?(cols, item_type, col_map)
          log("Malformed line.")
          return false
        end
      end
    end

    if col_map.empty?
      log("File rejected: header empty.")
      return false
    end

    true
  end

  # Check that a given line conforms with the header
  # and that the values are OK given the column.
  # Reject lines with no good OCN.
  # arg item_type not used and could/should be removed
  def well_formed_line?(cols, item_type, col_map)
    line_hash = {}

    if cols.size != col_map.keys.size
      log("Wrong number of cols (expected #{col_map.keys.size}, got #{cols.size})")
      return false
    end

    col_map.each do |col_type, i|
      validated_val = check_col_val(col_type, cols[i])
      if validated_val.empty? && col_type == "oclc"
        log("No usable OCNs in #{cols[i]} reject line [#{cols.join("\t")}]")
        return false
      end
      line_hash[col_type] = validated_val
    end

    line_hash["organization"] = @member_id
    line_hash["date_received"] = Time.new.strftime("%Y-%m-%d")
    line_hash["uuid"] = SecureRandom.uuid
    line_hash["mono_multi_serial"] = item_type
    output(line_hash.to_json)
    true
  end

  # Based on col type, pass on to the right method
  # to check if col val makes sense
  def check_col_val(col_type, col_val)
    case col_type
    when "oclc"
      @scrubfields.ocn(col_val)
    when "local_id"
      @scrubfields.local_id(col_val)
    when "status"
      @scrubfields.status(col_val)
    when "condition"
      @scrubfields.condition(col_val)
    when "govdoc"
      @scrubfields.govdoc(col_val)
    when "enumchron"
      @scrubfields.enumchron(col_val)
    when "issn"
      @scrubfields.issn(col_val)
    else
      raise ColValError, "check_col_val cannot handle column type #{col_type} (#{col_val})"
    end
  end

  # Check that the header line is present,
  # contains all required fields, optionally optional fields,
  # and nothing else.
  def well_formed_header?(header_cols, item_type)
    violations = 0

    header_cols = header_cols.map(&:downcase)
    log("Header cols: #{header_cols.join(", ")}")

    # Check that all required cols are present
    if REQ_HEADER_COLS & header_cols != REQ_HEADER_COLS
      log("Missing required header cols:#{(REQ_HEADER_COLS - header_cols).join(", ")}")
      violations += 1
    end

    unless OPT_HEADER_COLS.key?(item_type)
      log("Invalid item_type #{item_type}")
      violations += 1
    end

    # Note any cols that are not required/optional and ignore
    opt_for_type = OPT_HEADER_COLS[item_type] || []
    illegal_cols = (header_cols - (REQ_HEADER_COLS + opt_for_type))
    unless illegal_cols.empty?
      log("The following cols are not allowed: #{illegal_cols.join(",")}")
      violations += 1
    end

    if violations.positive?
      log "#{violations} violations in well_formed_header?"
    end

    violations.zero?
  end

  # Given a split header line like [a,b,c]
  # returns a hash {a=>1, b=>2, c=>3}
  def get_col_map(cols, item_type)
    col_map = {}
    possible_cols = REQ_HEADER_COLS + OPT_HEADER_COLS[item_type]

    cols.each_with_index do |col, i|
      if possible_cols.include?(col)
        col_map[col] = i
      else
        raise WellFormedHeaderError, "illegal col #{col} on pos #{i} in header"
      end
    end

    log("column_map: #{col_map}")

    col_map
  end

  # Check that the line has a decent number of cols.
  # This function is not used (yet) and may never be. Good axing candidate.
  def number_of_cols(cols)
    if cols.size < MIN_FILE_COLS
      log("Too few cols (#{cols.size} vs min #{MIN_FILE_COLS})")
      return false
    end
    if cols.size > MAX_FILE_COLS
      log("Too many cols (#{cols.size} vs max #{MAX_FILE_COLS})")
      return false
    end
    # Aaah, just right.
    log("Number of cols: #{cols.size}")
    true
  end

end

if $PROGRAM_NAME == __FILE__
  # Call thus: Autoscrub.new(member_id, *LIST_OF_FILE_PATHS)
  member_id = ARGV.shift
  as = Autoscrub.new(member_id, *ARGV)
  as.scrub_files
end
