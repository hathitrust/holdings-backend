# frozen_string_literal: true

require "cluster"
require "services"
require "shared_print/deprecation_record"
require "shared_print/deprecation_error"

module SharedPrint
  # Takes a file of (shared print) deprecation records,
  # and tries to match them to commitments
  # so that those commitments can be deprecated.
  # Usage: SharedPrint::Deprecator.new.run(<list_of_files>)
  class Deprecator
    attr_reader :err, :report, :report_path

    def initialize(verbose: false)
      raise "not implemented"
      @verbose = verbose
      @header_spec = ["organization", "ocn", "local_id", "deprecation_status"]
      clear_err
    end

    # Process a list of files.
    def run(args)
      args.each do |arg|
        from_file(arg)
      end
      @report&.close
    end

    # Read deprecation records from file and try to deprecate the matching commitments.
    def from_file(path)
      inf = File.open(path, "r")
      append_report "Reading deprecation records from #{path}"
      unless check_header(inf.gets.strip)
        append_report @err
        append_report "Stopped processing file #{inf} due to header error."
        return
      end
      inf.each_line do |line|
        try_deprecate(line.strip)
        Thread.pass
      rescue SharedPrint::DeprecationError => e
        append_report "Could not deprecate record. #{e}"
      end
    end

    # Deprecation files must have this header.
    def check_header(header_line)
      expected = @header_spec.join("\t")
      append_report "Checking header line: #{header_line}"
      if header_line != expected
        @err << [
          "Header not OK.",
          "Observed format:\t#{header_line}",
          "Expected format:\t#{expected}"
        ].join("\n")
        return false
      end

      append_report "Header OK"
      true
    end

    # Do what you can with a line, store errors in @err
    # return true if success / false otherwise
    def try_deprecate(line)
      clear_err
      dep = DeprecationRecord.parse_line(line)
      append_report "Find and deprecate a commitment based on the deprecation record: <#{dep}>."
      begin
        dep.find_commitment
      rescue SharedPrint::DeprecationError => e
        @err << e.message
      end

      # At this point we should have run out of reasons to reject the deprecation record,
      # and should have ended up with exactly one matching commitment, or errors.
      if dep.local_id_matches.size == 1
        matching_commitment = dep.local_id_matches.first
        matching_commitment.deprecate(status: dep.status)
        dep.cluster.save
        append_report "Commitment deprecated: #{matching_commitment.inspect}"
        true
      else
        append_report "Something failed:"
        append_report @err.join("\n")
        false
      end
    end

    def clear_err
      @err = []
    end

    private

    # Append messages to a report file, and to STDERR if @verbose
    def append_report(msg)
      if @report.nil?
        # To reduce the risk of accidental overwrites by a different instance,
        # make the filename rather unique-ish.
        iso_stamp = Time.now.strftime("%Y%m%d-%H%M%S")
        rand_str = SecureRandom.hex(8)
        report_dir = Settings.deprecation_report_path
        FileUtils.mkdir_p(report_dir)
        @report_path = "#{report_dir}/commitments_deprecator_#{iso_stamp}_#{rand_str}.txt"
        warn "Reporting to #{@report_path}" if @verbose
        @report = File.open(@report_path, "w")
      end
      @report.puts msg
      warn msg if @verbose
    end
  end
end
