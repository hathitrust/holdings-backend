require "securerandom"

# An attempt at simplifying the structure of report output dirs and files.
# Give report_name as input.
# The methods and their return:
#   id: the "unique-ish" part of the filename
#   dir: path to an output dir
#   file: path to an output file
#   handle("r"): an open read handle for file
#   handle("w"): an open write handle for file
# Both dir and file will contain the report name,
# and the file a timestamp and a unique-ish string.
# dir is autovivified with mkdir_p.
# Example:
# output = Utils::ReportOutput.new("foo", ".txt")
# output.dir # -> "/local_reports/foo"
# output.file # -> "/local_reports/foo/foo_YYYYMMDD_abcd1234.txt"

module Utils
  class ReportOutput
    attr_reader :report_name, :ext
    def initialize(report_name, ext = ".tsv")
      @report_name = report_name # e.g. "cost_report" or "cost_report_umich"
      @ext = ext
    end

    # IO for file
    def handle(rw) # "r", "w" etc
      File.open(file, rw)
    end

    # Full path to a file in a dir (a dir we are pretty sure exists)
    def file
      @file ||= File.join(dir, id) + ext
    end

    # mkdir to guarantee that it exists
    def dir
      @dir ||= dir_path.tap do |d|
        FileUtils.mkdir_p(d).first
      end
    end

    # Just the path
    def dir_path
      File.join(Settings.local_report_path || "/tmp", report_name)
    end

    def id
      if @id.nil?
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        # Adding a random string in case 2 identical jobs that write a file
        # are started in the same second.
        rand_str = SecureRandom.hex[0..8]
        # e.g. foo_YYYYMMDD_HHMMSS_abcd1234
        @id = [report_name, timestamp, rand_str].join("_")
      end
      @id
    end
  end
end
