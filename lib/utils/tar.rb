# frozen_string_literal: true

require "open3"

# A utility for dealing with .tar.gz files, used for processing member-submitted
# Alma holdings data.
# In spite of the name, this class only handles .tar.gz files, not plain .tar files.
# Thus far it does not appear we need to support the latter.
module Utils
  class Tar
    attr_reader :path
    TAR_EXE_PATH = "/usr/bin/tar"

    def initialize(path:)
      raise "not found: #{path}" unless File.exist?(path)

      @path = path
    end

    # List the files in a .tar.gz file
    def list
      stdout, stderr, status = Open3.capture3(TAR_EXE_PATH, "-tzPf", path)
      if !status.success?
        raise "could not list contents of tar file #{path}: status #{status}: stderr #{stderr}"
      end

      stdout.split("\n")
    end

    # Extract named file `file_name` to a new file at `destination_path`.
    # Uses the path to `tar` explicitly to bypass shell expansion
    # since `file_name` is tainted.
    def extract(file_name:, destination_path:)
      status = nil
      stderr_s = ""

      File.open(destination_path, "w") do |destination_file|
        Open3.popen3(TAR_EXE_PATH, "-xzf", path, file_name, "-O") do |stdin, stdout, stderr, wait_thr|
          stdin.close
          err_reader = Thread.new {
            stderr.read
          }
          out_reader = Thread.new {
            loop do
              bytes = stdout.readpartial(4096)
              destination_file.print bytes
              destination_file.flush
            rescue EOFError
              break
            end
          }
          stderr_s = err_reader.value
          out_reader.join
          status = wait_thr.value
        end
      end

      if !status.success? || File.size(destination_path).zero?
        raise "could not extract #{file_name} from #{path} to #{destination_path}: status #{status}: stderr #{stderr_s}"
      end
    end
  end
end
