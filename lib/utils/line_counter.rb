require "zlib"
# Instead of system calls to wc -l everywhere.
# Usage:
# Utils::LineCounter.count_file_lines(some_file) # -> number of lines (as an int)
module Utils
  class LineCounter
    def self.count_file_lines(path)
      raise IOError, "path #{path} does not point to existing file" unless File.exist?(path)

      if path.end_with?(".gz")
        Zlib::GzipReader
      else
        File
      end.open(path).count
    end
  end
end
