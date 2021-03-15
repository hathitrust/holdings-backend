# frozen_string_literal: true

require 'zinzout'
require 'services'
require "member_holding_header_factory"
require "custom_errors"
require "member_holding"

=begin

Context:

Objects of this class represent files submitted by (prospective)
members, to be loaded.

Individual lines are represented by MemberHolding objects.

Autoscrub generates MemberHoldingFile while scrubbing.

=end

class MemberHoldingFile
  attr_reader :error_count
  #private #perhaps
  attr_reader :col_map, :member_id, :filename, :filepath

  SPEC_RX = {
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

  def initialize(path)
    @filepath = path
    @filename = File.basename(path)
    @error_count = 0

    # get a file
    # check filename for member_id, item_type etc.
    # parse header & set up the column map
    # check individual lines
  end

  def log(str)
    Services.logger.info(str)
  end
  
  def parse
    @item_type = get_item_type_from_filename()
    @member_id = get_member_id_from_filename()

    unless valid_filename?
      raise FileNameError, "Invalid filename #{@filename}"
    end

    each_holding do |holding|
      puts holding.to_json
    end    
  end

  def get_member_id_from_filename(fn = @filename)
    if fn.nil? || fn.empty? then
      raise FileNameError, "Empty filename"
    end

    parts = fn.split("_")
    member_id = parts.first
    if SPEC_RX[:MEMBER_ID].match(member_id)
      return member_id
    else
      raise FileNameError, "Did not find a member_id in filename"
    end
  end

  def get_item_type_from_filename(fn = @filename)
    if SPEC_RX[:ITEM_TYPE_CONTEXT].match(filename)
      return Regexp.last_match(1)
    else
      raise FileNameError, "Did not find item_type in filename"
    end
  end

  # Check that a filename conforms to spec.
  def valid_filename?
    # If it matches, perfect, we don't need to analyze or report.
    log("Check filename #{@filename}")

    if SPEC_RX[:FILENAME].match?(@filename)
      log("Filename #{@filename} OK!")
      return true
    end

    # If we made it here, the match failed, so break it down & return false.
    (f_member_id, f_item_type, f_update_type, f_date_str, *f_rest) =
      @filename.split(SPEC_RX[:FILENAME_PART_DELIM])

    log([
      "Processing of #{@filename} failed due to filename errors.",
      "Filename must match the template:",
      "<member_id>_<item_type>_<update_type>_<date_str>_<rest>",
      "Filename was analyzed as:",
      "member_id\t\"#{f_member_id}\"\t#{analyze_member_id(f_member_id)}",
      "item_type\t\"#{f_item_type}\"\t#{analyze_item_type(f_item_type)}",
      "update_type\t\"#{f_update_type}\"\t#{analyze_update_type(f_update_type)}",
      "date_str\t\"#{f_date_str}\"\t#{analyze_date_str(f_date_str)}",
      "rest\t\"#{f_rest.join(" ")}\"\t#{analyze_rest(f_rest)}"
    ].join("\n"))

    return false
  end

  def analyze_member_id(str)
    err_msg = "must be all a-z+"
    not_nil_and_match(str, SPEC_RX[:MEMBER_ID], err_msg)
  end

  def analyze_item_type(str)
    err_msg = "must be mono|multi|serial"
    not_nil_and_match(str, SPEC_RX[:ITEM_TYPE], err_msg)
  end

  def analyze_update_type(str)
    err_msg = "must be full|partial"
    not_nil_and_match(str, SPEC_RX[:UPDATE_TYPE], err_msg)
  end

  def analyze_date_str(str)
    err_msg = "must be 8 digits"
    not_nil_and_match(str, SPEC_RX[:DATE], err_msg)
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

  def each_holding
    read_file do |line, line_no, col_map|
      yield item_from_line(line, col_map)
    end
  end

  def item_from_line(line, col_map)
    if line.nil? || line.class != String || line.empty?
      raise "bad line"
    end

    holding = MemberHolding.new(col_map)
    holding.parse_str(line)
    holding.organization = @member_id
    holding.mono_multi_serial = @item_type

    return holding
  end

  def read_file
    Zinzout.zin(filepath) do |fh|
      header = MemberHoldingHeaderFactory
                 .new(@item_type, fh.readline)
                 .get_instance
      col_map = header.get_col_map()
      line_no = 0
      fh.each_line do |line|
        line_no += 1
        line.chomp!
        yield line, line_no, col_map
      end
    end
  end

end
