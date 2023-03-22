require "open3"
require "securerandom"

# A class for knowing (uchardet) and changing (iconv) the encoding
# of a file

module Utils
  class Encoding
    attr_reader :path, :encoding, :utf8_output, :diff
    def initialize(path)
      @path = path
      if @path.nil?
        raise IOError, "Nil file given"
      end
      unless File.exist?(@path)
        raise IOError, "No valid file given (#{@path.inspect})"
      end
      @encoding = uchardet
      # Set by force_utf8
      @utf8_output = nil
      @diff = nil
    end

    # If a file is utf8 or ascii, then we can load it w/o conversion.
    def ascii_or_utf8?
      ["ASCII", "UTF-8"].include? @encoding
    end

    # Takes an input path to a file and forces it into utf8, discarding
    # any "illegal input sequence" from the output.
    # Writes output and diff to files in /tmp/.
    # Returns bool.
    def force_utf8
      # Start by unzipping input
      unzipped_input = "/tmp/Utils_Encoding_in_#{SecureRandom.uuid}"
      output = "/tmp/Utils_Encoding_out_#{SecureRandom.uuid}"
      diff = "/tmp/Utils_Encoding_diff_#{SecureRandom.uuid}"
      `zcat -f '#{@path}' > #{unzipped_input}`
      # and forcibly converting it to UTF-8
      iconv_cmd = "iconv #{unzipped_input} -f #{@encoding} -t utf8 -c > #{output}"

      # Check iconv output for errors
      res = capture_outs(iconv_cmd)[:stderr]
      unless res.empty?
        raise EncodingError, res
      end

      # Then get the diff input <> output
      `diff #{unzipped_input} #{output} | grep -P '^>' > #{diff}`
      @diff = diff
      # Clean up
      FileUtils.rm(unzipped_input)
      # Return the path of the unzipped and converted output
      @utf8_output = output
      true
    rescue
      false
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
