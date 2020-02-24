require 'ht_members'
require 'zlib'

class Autoscrub
  @@data_dir = __dir__ + "/../testdata"
  
  @@filename_regexp = Regexp.new(
    /^[a-z\-]+_(mono|multi|serial)_(full|partial)_\d{8}(_.+)?.tsv(.gz)?$/
  )

  @@req_header_cols = %w<oclc local_id>
  @@opt_header_cols = {
    'mono'   => %w<status condition govdoc>,
    'multi'  => %w<status condition govdoc enumchron>,
    'serial' => %w<govdoc issn>
  }

  @@min_file_cols = 2
  @@max_file_cols = 6
  
  def initialize(member_id, *files)
    if !valid_member_id?(member_id) then
      raise ArgumentError.new("Bad member_id #{member_id}")
    end
    @member_id = member_id

    files.each do |f|
      if !valid_filename?(f) then
        raise ArgumentError.new("Bad file #{f}")
      end
    end
    @files = files

    @ht_members = Ht_members.new()
  end

  def valid_member_id?(member_id)
    # Tie in data store wrapper that checks for valid members
    true
  end

  def valid_filename?(filename)
    # If it matches, perfect, we don't need to analyze or report.

    # !!str.match(/regexp/) is the easiest (?!) way to get a bool
    # regexp match in ruby.
    if !!filename.match(@@filename_regexp) then
      return true
    end

    (member_id, item_type, update_type, date_str, *rest) =
      filename.split(/[_\.]/)

    STDERR.puts(
      [
        "Filename #{filename} analyzed as:",
        "member_id:#{member_id} #{analyze_member_id(member_id)}",
        "item_type:#{item_type} #{analyze_item_type(item_type)}",
        "update_type:#{update_type} #{analyze_update_type(update_type)}",
        "date_str:#{date_str} #{analyze_date_str(date_str)}",
        "rest:#{rest} #{analyze_rest(rest)}",
      ]
    )

    return false
  end

  def analyze_member_id (str)
    return 'must not be empty' if str.nil?
    !!str.match(/^[a-z\_]+$/) ? 'ok' : 'not ok, must be a-z+'
  end

  def analyze_item_type (str)
    return 'must not be empty' if str.nil?
    !!str.match(/^(mono|multi|serial)$/) ?
      'ok' : 'not ok, must be mono|multi|serial'
  end

  def analyze_update_type (str)
    return 'must not be empty' if str.nil?
    !!str.match(/^(full|partial)$/) ?
      'ok' : 'not ok, must be full|partial'
  end

  def analyze_date_str (str)
    return 'must not be empty' if str.nil?
    !!str.match(/^\d{8}$/) ? 'ok' : 'not ok, must be 8 digits'
  end

  # We allow the 'rest' to contain arbitrary labels, it just has to end
  # with our required file extension(s).
  def analyze_rest (arr)
    return 'must not be empty' if arr.empty?

    if arr.size > 10 || arr.join().length > 100 then
      return 'not ok, too long'
    end

    if arr[-1] == 'tsv' || (arr[-2] == 'tsv' && arr[-1] == 'gz') then
      return 'ok'
    end

    return 'not ok, must end in .tsv or .tsv.gz'
  end

  # Opens a text file (optionally zipped) and yields one chomped
  # line at a time (together with line number)
  def read_file (filename)
    line_no = 0
    (filename =~ /\.gz$/ ? Zlib::GzipReader : File)
      .open("#{@@data_dir}/#{filename}").each_line do |line|
      line_no += 1
      line.chomp!
      yield line, line_no
    end
  end

  # Given filename, determine mono/multi/serial.
  # Returns empty string as failure.
  def get_item_type (filename)
    item_type = ""
    if filename =~ /_(mono|multi|serial)_/ then
      item_type = $1
    else
      STDERR.print "Did not find item_type in filename"
    end
    return item_type
  end

  # Check that a file has a header line, consistent number
  # of cols, lines that are not too long.
  def well_formed_file? (filename)
    STDERR.puts "Checking well-formedness of #{filename}"

    # mono/multi/serial
    item_type = get_item_type(filename)

    # Stores which col is where, based on header line.
    col_map = {}

    read_file(filename) do |line, line_no|
      line.chomp!
      puts line
      cols = line.split("\t")
      
      # Check header line.
      if line_no == 1 then
        if !well_formed_header?(cols, item_type) then
          return false
        end
        col_map = get_col_map(cols, item_type)
      else
        if !well_formed_line?(cols, item_type, col_map) then
          return false
        end
      end
      
    end

    return true
  end


  def well_formed_line? (cols, item_type, col_map)
    puts "col map: #{col_map}"
    puts "cols #{cols.join(',')}"
    col_map.each do |col_type, i|
      puts "check that col #{i} (#{col_type}) has an OK value #{cols[i]}"
      check_col_val(col_type, cols[i])
    end

    false
  end

  # Based on col type, check if col val makes sense
  def check_col_val (col_type, col_val)
    case col_type
    when "oclc"
      not_implemented(col_val)
    when "local_id"
      not_implemented(col_val)
    when "status"
      not_implemented(col_val)
    when "condition"
      not_implemented(col_val)
    when "govdoc"
      not_implemented(col_val)
    when "enumchron"
      not_implemented(col_val)
    when "issn"
      not_implemented(col_val)
    else
      raise "not covered this case: #{col_type} : #{col_val}"
    end
  end

  def not_implemented (*x)
    puts "not implemented"
  end
  
  # Check that the header line is present,
  # contains all required fields, optionally optional fields,
  # and nothing else.
  def well_formed_header?(header_cols, item_type)
    pass = true

    # Check that all required cols are present
    if @@req_header_cols & header_cols != @@req_header_cols then
      STDERR.puts "Missing required header cols:" +
                  (@@req_header_cols - header_cols).join(', ')
      pass = false
    end

    # Note any cols that are not required/optional and ignore
    opt_for_type = @@opt_header_cols[item_type] || []
    STDERR.puts "Optional fields for #{item_type}: #{opt_for_type.join(', ')}"
    illegal_cols = (header_cols - (@@req_header_cols + opt_for_type))
    if illegal_cols.size > 0 then
      STDERR.puts "The following cols are not allowed: #{illegal_cols.join(',')}"
      pass = false
    end
    
    return pass
  end

  # Given a split header line like [a,b,c]
  # returns a hash {a=>1, b=>2, c=>3}
  def get_col_map (cols, item_type)
    puts "getting col map"
    col_map = {}
    possible_cols = @@req_header_cols + @@opt_header_cols[item_type]

    cols.each_with_index do |col, i|
      if possible_cols.include?(col) then
        col_map[col] = i
      else
        raise Error.new("illegal col #{col} on pos #{i} in header")
      end
    end
    
    return col_map
  end
  
  # Check that the line has a decent number of cols.
  def number_of_cols (cols)
    if cols.size < @@min_file_cols then
      STDERR.puts "Too few cols (#{cols.size} vs min #{@@min_file_cols})"
      return false
    end
    if cols.size > @@max_file_cols then
      STDERR.puts "Too many cols (#{cols.size} vs max #{@@max_file_cols})"
      return false
    end

    return true
  end

end
