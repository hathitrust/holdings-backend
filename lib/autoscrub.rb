# frozen_string_literal: true

require "zlib"
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

class Autoscrub
  # Todo: read these dir paths from config/env?
  DATA_DIR = __dir__ + "/../testdata"
  LOG_DIR  = __dir__ + "/../testdata"
  
  SPEC_REGEXP = {
    # A single regex for file name pass/fail.
    :FILENAME => /^
    [a-z\-]+              # member_id
    _(mono|multi|serial)  # item_type
    _(full|partial)       # update_type
    _\d{8}                # date_str (loosest possible YYYYMMDD check)
    (_.+)?                # optional "rest" part
    .tsv                  # must have a .tsv extension
    (.gz)?                # may have a .gz extension
    $/x.freeze,

    # Split filename on these to get the individual parts.
    :FILENAME_PART_DELIM => /[_\.]/.freeze,

    # If filename fail, further regexes to discover why.
    :MEMBER_ID         => /^[a-z\_\-]+$/.freeze,
    :ITEM_TYPE         => /^(mono|multi|serial)$/.freeze,
    :ITEM_TYPE_CONTEXT => /_(mono|multi|serial)_/.freeze,
    :UPDATE_TYPE       => /^(full|partial)$/.freeze,

    # A YYYYMMDD date string is expected,
    # and of course this regex is overly permissive
    # but let's leave it like that.
    :DATE => /^\d{8}$/.freeze,
  }

  # Required header columns for all files
  REQ_HEADER_COLS = %w[oclc local_id].freeze

  # Optional header columns per item_type
  OPT_HEADER_COLS = {
    "mono"   => %w[status condition govdoc],
    "multi"  => %w[status condition govdoc enumchron],
    "serial" => %w[govdoc issn]
  }.freeze

  MIN_FILE_COLS = 2
  MAX_FILE_COLS = 6

  # Give a member_id and a list of files.
  def initialize(member_id, *files)
    # Check that member_id is valid
    if !valid_member_id?(member_id) then
      raise MemberIdError, "Bad member_id #{member_id}"
    end

    @member_id  = member_id
    @files      = files
    @out_file   = nil
    @log_file   = nil
    date        = Time.now.strftime('%Y%m%d')
    master_log_name = "master_#{@member_id}_#{date}"
    @master_log = get_log_file(master_log_name)
    $stderr.puts "Logging to #{File.expand_path(@master_log.path)}"

    @scrubfields = ScrubFields.new
    
    mlog("Received #{@files.size} files")
    @files.each do |f|
      mlog(f)
    end
  end

  # DRY code for output, log, mlog
  # Writes to handle if you can, otherwise to stdout
  def p_file_or_stderr(handle, str)
    caller_func = caller.first.split(' ').last
    if handle.nil? then
      puts "(#{caller_func}) #{str}"
    else
      handle.puts(str)
    end
  end
  
  # Writes string to @out_file, if defined, else to STDOUT.
  def output (str)
    p_file_or_stderr(@out_file, str)
  end

  # Writes string to @log_file, if defined, else to STDERR.
  # TODO: real logger
  def log (str)
    p_file_or_stderr(@log_file, str)
  end

  # Writes string to @master_log, if defined, else to STDERR.
    # TODO: real logger
  def mlog (str)
    p_file_or_stderr(@master_log, str)
  end

  def scrub_file(f)
    # TODO: extract a single-file scrubber to a separate class
    raise FileNameError if !valid_filename?(File.basename(f))
    @out_file = get_out_file(f)
    @log_file = get_log_file(f)
    raise WellFormedFileError if !well_formed_file?(f)
  end

  # Goes through the files given to initialize
  # Returns a hash of {f1=>BOOL, ..., fn=>BOOL}
  # where key=file and BOOL=success.
  def scrub_files
    file_success = {}
    @files.each do |f|
      mlog("Scrubbing #{f}")
      begin
        scrub_file(f)
        file_success[f] = true
      rescue StandardError => e
        mlog("Input file #{f} rejected, reason: #{e} #{e.message}")
        file_success[f] = false
      rescue SystemCallError => e
        mlog("something wrong with file #{f}?")
        file_success[f] = false
      ensure

        log(@scrubfields.stats_to_str)
        @scrubfields.clear_stats
        
        @out_file.close() if @out_file.methods.include?(:close)
        @out_file = nil
        @log_file.close() if @log_file.methods.include?(:close)
        @log_file = nil
      end
    end
    return file_success
  end

  # Check that the member_id points to a member in the data store
  def valid_member_id?(member_id)
    # Tie in data store wrapper that checks for valid members
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
    log("returning #{ret}")
    return ret
  end

  # Check that a filename conforms to spec.
  def valid_filename?(filename)
    # If it matches, perfect, we don't need to analyze or report.
    if filename.start_with?(@member_id) &&
       SPEC_REGEXP[:FILENAME].match?(filename) then
      return true
    end

    # If we made it here, the match failed, so break it down & return false.
    (member_id, item_type, update_type, date_str, *rest) =
      filename.split(SPEC_REGEXP[:FILENAME_PART_DELIM])

    # mlog because @log is not open when this is called
    mlog([
          "Processing of #{filename} failed due to filename errors.",
          "Filename must match the template:",
          "<member_id>_<item_type>_<update_type>_<date_str>_<rest>",
          "Filename was analyzed as:",
          "member_id\t\"#{member_id}\"\t#{analyze_member_id(member_id)}",
          "member_id\t\"#{member_id}\"\t#{file_belong_to_member(member_id)}",
          "item_type\t\"#{item_type}\"\t#{analyze_item_type(item_type)}",
          "update_type\t\"#{update_type}\"\t#{analyze_update_type(update_type)}",
          "date_str\t\"#{date_str}\"\t#{analyze_date_str(date_str)}",
          "rest\t\"#{rest.join(' ')}\"\t#{analyze_rest(rest)}"
        ].join("\n"))

    return false
  end

  def analyze_member_id(str)
    not_nil_and_match(str, SPEC_REGEXP[:MEMBER_ID], "must be all a-z+")
  end

  def file_belong_to_member(member_id)
    not_nil_and_match(member_id, /^#{@member_id}$/, "must match @member_id (#{@member_id})")
  end
  
  def analyze_item_type(str)
    not_nil_and_match(str, SPEC_REGEXP[:ITEM_TYPE], "must be mono|multi|serial")
  end

  def analyze_update_type(str)
    not_nil_and_match(str, SPEC_REGEXP[:UPDATE_TYPE], "must be full|partial")
  end

  def analyze_date_str(str)
    not_nil_and_match(str, SPEC_REGEXP[:DATE], "must be 8 digits")
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
    if arr.size > 10 || arr.join.length > 100 then
      return "not ok, too long"
    end
    
    if arr[-1] == "tsv" || (arr[-2] == "tsv" && arr[-1] == "gz") then
      return "ok"
    end

    return "not ok, must end in .tsv or .tsv.gz"
  end

  # Opens a new outfile in DATA_DIR with a name based on the infile
  def get_out_file(filename)
    out_filename = filename.gsub(/^.+\//, "").gsub(/\.gz$/, "")
    out_filename.concat(".out.ndj")
    mlog("Opening output file #{DATA_DIR}/#{out_filename}")
    return File.open("#{DATA_DIR}/#{out_filename}", "w")
  end

  # Opens a new logfile in LOG_DIR with a name based on the infile
  def get_log_file(filename)
    log_filename = filename.gsub(/^.+\//, "").gsub("\.gz", "").gsub("\.tsv","")
    today = Time.now.strftime("%Y%m%d")
    log_filename.concat("_#{today}.log.txt")
    mlog("Opening log file #{LOG_DIR}/#{log_filename}")
    return File.open("#{LOG_DIR}/#{log_filename}", "w")
  end

  # Opens a text file (optionally zipped) and yields one chomped
  # line at a time (together with line number)
  # That's right, chomp not strip, since we care about empty cols too.
  def read_file(filename)
    line_no = 0

    # Any filename or relative path will be relative to DATA_DIR
    # but absolute paths are absolute.
    file_path = "#{DATA_DIR}/#{filename}"
    if filename.include?("/") then
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
    if SPEC_REGEXP[:ITEM_TYPE_CONTEXT].match(filename) then
      item_type = Regexp.last_match(1)
    else
      log("Did not find item_type in filename")
    end
    return item_type
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
      if line_no == 1 then
        if !well_formed_header?(cols, item_type) then
          log("File rejected: header not OK.")
          return false
        end
        # header was ok, set col_map
        log("Header OK.")
        col_map = get_col_map(cols, item_type)
      else
        # All other lines:
        return false if !well_formed_line?(cols, item_type, col_map)
      end
    end

    return false if col_map.empty?    
    return true
  end

  # Check that a given line conforms with the header
  # and that the values are OK given the column.
  # Reject lines with no good OCN.
  # arg item_type not used and could/should be removed
  def well_formed_line?(cols, item_type, col_map)
    line_hash = {}

    if cols.size != col_map.keys.size then
      log("Wrong number of cols (expected #{col_map.keys.size}, got #{cols.size})")
      return false
    end

    col_map.each do |col_type, i|
      validated_val = check_col_val(col_type, cols[i])
       ##################################
      ## collect stats on col vals here ##
       ##################################      
      if validated_val.empty? && col_type == "oclc" then
        log("No usable OCNs in #{cols[i]} reject line [#{cols.join("\t")}]")
        return false
      end
      line_hash[col_type] = validated_val
    end
    
    output(line_hash)
    return true
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

    header_cols = header_cols.map{|x| x.downcase}
    log("Header cols: #{header_cols.join(", ")}")

    # Check that all required cols are present
    if REQ_HEADER_COLS & header_cols != REQ_HEADER_COLS then
      log("Missing required header cols:" + \
          (REQ_HEADER_COLS - header_cols).join(", "))
      violations += 1
    end

    if !OPT_HEADER_COLS.key?(item_type) then
      log("Invalid item_type #{item_type}")
      violations += 1
    end

    # Note any cols that are not required/optional and ignore
    opt_for_type = OPT_HEADER_COLS[item_type] || []
    illegal_cols = (header_cols - (REQ_HEADER_COLS + opt_for_type))
    if !illegal_cols.empty? then
      log("The following cols are not allowed: #{illegal_cols.join(",")}")
      violations += 1
    end

    if violations.positive? then
      log "#{violations} violations in well_formed_header?"
    end

    return violations.zero?
  end

  # Given a split header line like [a,b,c]
  # returns a hash {a=>1, b=>2, c=>3}
  def get_col_map(cols, item_type)
    col_map = {}
    possible_cols = REQ_HEADER_COLS + OPT_HEADER_COLS[item_type]

    cols.each_with_index do |col, i|
      if possible_cols.include?(col) then
        col_map[col] = i
      else
        raise WellFormedHeaderError, "illegal col #{col} on pos #{i} in header"
      end
    end

    log("column_map: #{col_map}")
    
    return col_map
  end

  # Check that the line has a decent number of cols.
  # This function is not used (yet) and may never be. Good axing candidate.
  def number_of_cols(cols)    
    if cols.size < MIN_FILE_COLS then
      log("Too few cols (#{cols.size} vs min #{MIN_FILE_COLS})")
      return false
    end
    if cols.size > MAX_FILE_COLS then
      log("Too many cols (#{cols.size} vs max #{MAX_FILE_COLS})")
      return false
    end
    # Aaah, just right.
    log("Number of cols: #{cols.size}")
    return true
  end

end

if $0 == __FILE__ then
  member_id = ARGV.shift
  as = Autoscrub.new(member_id, *ARGV)
  as.scrub_files()
end
