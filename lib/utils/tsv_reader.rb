module Utils
  class TSVReader
    # Takes a .tsv file with a header and turns it into hashes,
    # where the keys are from the header and the values from the body cells.
    # E.g.:
    #   ocn <tab> local_id
    #   11 <tab> i11
    #   ...
    #   99 <tab> i99
    # ... into:
    # [{ocn: 11, local_id: i11} ... {ocn: 99, local_id: i99}]
    attr_reader :path, :header, :header_index
    def initialize(path, delim = "\t")
      @path = path
      @delim = delim
    end

    def run
      @inf = File.open(@path, "r")
      process_header
      records do |r|
        yield r
      end
      @inf.close
    end

    def process_header(line = @inf.gets.strip)
      @header = line
      @header_hash = {}
      @header_index = {}
      # Set up header_index  = {0: ocn, 1: local_id}
      # and header_hash = {ocn: nil, local_id: nil}
      @header.split(@delim).each_with_index do |col_head, i|
        @header_index[i] = col_head.to_sym
        @header_hash[col_head.to_sym] = nil
      end
    end

    def records
      # For each line, get a copy of header_hash and populate it using header_index
      # so that cols_hash = {ocn: 11, local_id: i11}
      @inf.each_line do |line|
        yield line_to_hash(line.strip)
      end
    end

    def line_to_hash(line)
      cols = line.split(@delim)
      if cols.size != @header_hash.keys.size
        raise IndexError, "Line cols: #{cols.size}, header cols: (#{@header_hash.keys.size})."
      end
      col_hash = @header_hash.clone
      cols.each_with_index do |col_val, i|
        col_hash[@header_index[i]] = col_val
      end

      col_hash.compact
    end
  end
end
