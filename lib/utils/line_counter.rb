# Instead of system calls to wc -l everywhere.
# Usage:
# Utils::LineCounter.new(some_file).count_lines # -> number of lines (as an int)
require "utils/agnostic_opener"

module Utils
  class LineCounter
    def initialize(path)
      @path = path
      unless File.exist?(@path)
        raise IOError, "path #{@path} does not point to existing file"
      end
    end

    def count_lines
      Utils::AgnosticOpener.new(@path).open do |file|
        file.count
      end
    end
  end
end
