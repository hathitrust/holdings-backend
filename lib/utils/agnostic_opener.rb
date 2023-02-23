require "securerandom"

# Yet Another IO Wrapper.
# Open files regardless of their:
# * gzippedness,
# * newline style
# * or whether or not they have a UTF8 BOM
# Example:
# Utils::AgnosticOpener.new(path).readlines { |line| ... }

module Utils
  class AgnosticOpener
    attr_reader :path, :tmp_path

    def initialize(path)
      @path = path
      @orig_path = path
      @tmp_path = nil

      if @path.nil?
        raise ArgumentError, "path is nil"
      end
      unless File.exist?(@path)
        raise ArgumentError, "path not file"
      end
    end

    def readlines
      return enum_for(:readlines) unless block_given?
      open do |file|
        file.each_line do |line|
          yield line
        end
      end
    end

    def open
      return enum_for(:open) unless block_given?
      ensure_uncompressed
      # Could probably inject iconv shenanigans >>here<<
      # if we want to add support for the UTF-16s.
      File.open(@path, encoding: "BOM|UTF-8", universal_newline: true) do |file|
        yield file
      end
    ensure
      cleanup!
    end

    def ensure_uncompressed
      if gz?
        @tmp_path = "/tmp/agnostic_opener:#{SecureRandom.uuid}"
        `zcat "#{@path}" > #{@tmp_path}`
        @path = @tmp_path
      end
    end

    def gz?
      @path.end_with?(".gz")
    end

    def cleanup!
      unless @tmp_path.nil?
        FileUtils.rm(@tmp_path)
        @path = @orig_path
      end
    end
  end
end
