require "open3"
require "securerandom"

# A class for knowing (uchardet) and changing (iconv) the encoding
# of a file

module Utils
  class Encoding
    def initialize(path)
      @path = path
      if @path.nil?
        raise IOError, "Nil file given"
      end
      unless File.exist?(@path)
        raise IOError, "No valid file given (#{@path.inspect})"
      end
      @encoding = uchardet
    end

    # If a file is utf8 or ascii, then we can load it w/o conversion.
    def ascii_or_utf8?
      ["ASCII", "UTF-8"].include? @encoding
    end

    # Takes an input path to a file and forces it into utf8, discarding
    # any "illegal input sequence" from the output.
    # Writes output to a file in /tmp/.
    def force_utf8
      out = "/tmp/#{SecureRandom.uuid}"
      cmd = "zcat -f '#{@path}' | iconv -f #{uchardet} - -t utf8 -c > #{out}"
      res = capture_outs(cmd)[:stderr]
      unless res.empty?
        raise EncodingError, res
      end
      out
    end

    # Execute command and return its stat, stderr and stdout in a hash.
    # iconv will complain in stderr which backticks would miss.
    def capture_outs(cmd)
      stdout, stderr, stat = Open3.capture3(cmd)

      {
        stat: stat.to_i,
        stderr: stderr.strip,
        stdout: stdout.strip
      }
    end

    # Get the name of the encoding of the file.
    def uchardet
      `zcat -f '#{@path}' | uchardet`.strip
    end
  end
end
