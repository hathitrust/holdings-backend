require "shared_print/finder"
require "shared_print/replace_record"
require "clusterable/commitment"
require "utils/tsv_reader"

module SharedPrint
  # Members can send files of replace_records, which each identify an existing
  # shared print commitment and something to replace it with.
  # This class takes such files and processes them.
  # A file of replace_records should have a header that contains the columns:
  # [replace_organization, replace_ocn, replace_local_id] to identify
  # the original commitment, and then the same columns that a shared print commitment
  # file has.
  class Replacer
    attr_reader :report_path
    def initialize(path)
      raise "not implemented"
      @path = path
    end

    # Take a file and make SharedPrint::ReplaceRecords out of each line, apply & report.
    def run
      report "Started #{@path}"
      Utils::TSVReader.new(@path).run do |record|
        report record
        finder_args = {
          ocn: [record.delete(:replace_ocn).to_i],
          organization: [record.delete(:replace_organization)],
          local_id: [record.delete(:replace_local_id)],
          deprecated: nil
        }
        existing = SharedPrint::Finder.new(**finder_args).commitments.to_a.first
        rep_rec = SharedPrint::ReplaceRecord.new(existing: existing, replacement: record)
        report rep_rec.to_s
        rep_rec.apply
        report "Success: #{rep_rec.verify}"
        report rep_rec.replaced.inspect
        Thread.pass
      rescue ArgumentError => err
        report "Could not replace. #{err.message}"
      rescue IndexError => err
        report "Could not replace. #{err.message}"
      end
      report "Finished #{@path}"
      @report&.close
    end

    private

    # Report to file, set up if not set up.
    def report(msg)
      if @report.nil?
        report_dir = Settings.replace_commitment_report_path
        FileUtils.mkdir_p(report_dir)
        rand_str = SecureRandom.hex(8)
        iso_stamp = Time.now.strftime("%Y%m%d-%H%M%S")
        @report_path = "#{report_dir}/#{iso_stamp}_#{rand_str}.txt"
        @report = File.open(@report_path, "w")
        Services.logger.info "#{self.class} reporting to #{@report_path}"
      end
      @report.puts msg
    end
  end
end
