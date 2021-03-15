require 'zinzout'
require 'services'

class MemberHoldingFile
  attr_reader :error_count

  ITEM_TYPE_CONTEXT = /_(mono|multi|serial)_/.freeze

  # Required header columns for all files
  REQ_HEADER_COLS = ["oclc", "local_id"].freeze

  # Optional header columns per item_type
  OPT_HEADER_COLS = {
    "mono"   => ["status", "condition", "govdoc"],
    "multi"  => ["status", "condition", "govdoc", "enumchron"],
    "serial" => ["govdoc", "issn"]
  }.freeze

  def log(whatever)
    Services.logger.info(whatever)
  end

  def initialize(path)
    @filepath = path
    @filename = File.basename(path)
    @error_count = 0
    # open
    # parse header & set up the column map
    # set the item type
  end

  def item_type
    @item_type ||= if ITEM_TYPE_CONTEXT.match(filename)
      Regexp.last_match(1)
    else
      raise "Did not find item_type in filename"
    end
  end

  def each_holding
    read_file do |line|
      yield item_from_line(line)
    end
  end

  private

  attr_reader :col_map, :member_id, :filename, :filepath

  # Given a split header line like [a,b,c]
  # returns a hash {a=>1, b=>2, c=>3}
  def get_col_map(cols)
    col_map = {}
    possible_cols = REQ_HEADER_COLS + OPT_HEADER_COLS[item_type]

    cols.each_with_index do |col, i|
      if possible_cols.include?(col)
        col_map[col] = i
      else
        raise "illegal col #{col} on pos #{i} in header"
      end
    end
    if col_map.empty?
      raise "File rejected: header empty."
    end

    log("column_map: #{col_map}")

    col_map
  end

  def item_from_line(line)
    return unless line.chomp!

    cols = line.split("\t")
    holding = MemberHolding.new

    if cols.size != col_map.keys.size
      log("Wrong number of cols (expected #{col_map.keys.size}, got #{cols.size})")
      @error_count += 1
      return false
    end

    col_map.each do |col_type, i|
      validated_val = check_col_val(col_type, cols[i])
      if validated_val.empty? && col_type == "oclc"
        log("No usable OCNs in #{cols[i]} reject line [#{cols.join("\t")}]")
        @error_count += 1
        return false
      end
      holding.public_send("#{col_type}=",validated_val)
    end

    holding.organization = member_id
    holding.mono_multi_serial = item_type

    holding
  end

  def parse_header(line)
    cols = line.chomp.split("\t")
    unless well_formed_header?(cols)
      log("File rejected: header not OK.")
      return false
    end
    # header was ok, set col_map
    log("Header OK.")
    col_map = get_col_map(cols)
  end

  def read_file
    Zinzout.zin(filepath) do |fh|
      parse_header(fh.readline) unless fh.eof?

      line_no = 1
      fh.each_line do |line|
        line_no += 1
        line.chomp!
        yield line, line_no
      end
    end
  end

  # Check that the header line is present,
  # contains all required fields, optionally optional fields,
  # and nothing else.
  def well_formed_header?(header_cols)
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
end
