require "zlib"
# Instead of system calls to wc -l everywhere.
# Usage:
# Utils::LineCounter.new(some_file).count_lines # -> number of lines (as an int)
module Utils
  class LineCounter
    def initialize(path)
      @path = path
      unless File.exist?(@path)
        raise IOError, "path #{@path} does not point to existing file"
      end
    end

    # Determine which class to open with
    def io
      if @path.end_with?(".gz")
        Zlib::GzipReader
      else
        File
      end
    end

    def count_lines
      io.open(@path) do |file|
        file.count
      end
    end
  end
end
