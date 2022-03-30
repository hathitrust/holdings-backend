# frozen_string_literal: true

require "shared_print/finder"
require "shared_print/update_record"
require "utils/tsv_reader"

Services.mongo!

module SharedPrint
  # Takes update records, tries to find them and applies updates when successful.
  class Updater
    attr_reader :file, :report_path
    def initialize(file)
      @file = file
    end

    # Process each record in @file.
    def run
      report "Update commitments based on update records in #{file}"
      Utils::TSVReader.new(@file).run do |rec|
        report "{"
        process_record(rec)
        report "}"
      end
      report "Done with #{file}."
    end

    # Report to file, set up if not set up.
    def report(msg)
      if @report.nil?
        report_dir = Settings.shared_print_update_report_path
        FileUtils.mkdir_p(report_dir)
        in_base = File.basename(@file, ".*")
        in_ext = File.extname(@file)
        rand_str = SecureRandom.hex(8)
        iso_stamp = Time.now.strftime("%Y%m%d-%H%M%S")
        @report_path = "#{report_dir}/#{in_base}_#{iso_stamp}_#{rand_str}#{in_ext}"
        warn "Reporting to #{@report_path}"
        @report = File.open(@report_path, "w")
      end
      @report.puts msg
    end

    # Takes a single update record...
    def process_record(update_hash)
      @update_record = SharedPrint::UpdateRecord.new(update_hash)
      # ... and tries to find commitments that match.
      report "Using #{@update_record.finder_fields}, find & update #{@update_record.updater_fields}"
      @finder = SharedPrint::Finder.new(**@update_record.finder_fields)
      @commitments = @finder.commitments.to_a
      apply
    end

    # Applies the updates found in the update record onto the commitment.
    def apply
      case @commitments.size
      when 1
        apply_single_update
      when 0
        relax_search
      else
        too_many_hits
      end
    end

    # Apply a set of changes from 1 SharedPrint::UpdateRecord to one Clusterable::Commitment.
    def apply_single_update
      commitment = @commitments.first
      @update_record.updater_fields.each do |k, v|
        report "updating #{k}=#{v}"
        commitment.send("#{k}=", v)
      end
      report "OK."
      commitment.save
    end

    # Removes local_id from search and tries finding commitments again.
    def relax_search
      report "Can only apply updates to 1 commitment. Full search found #{@commitments.size}."
      if @finder.local_id.any?
        report "Full search:\t#{@update_record.finder_fields.inspect}"
        relaxed_search = @update_record.finder_fields.except(:local_id)
        report "Relaxed:\t#{relaxed_search.inspect}"
        relaxed_finder = SharedPrint::Finder.new(**relaxed_search)
        relaxed_commitments = relaxed_finder.commitments.to_a
        report "Relaxed search found #{relaxed_commitments.size} commitments."
        if relaxed_commitments.any?
          relaxed_commitments.each do |rc|
            # could call apply here and be done with it.
            report rc.inspect
          end
        end
      end
    end

    def too_many_hits
      report "Can only apply updates to 1 commitment. Full search found #{@commitments.size}:"
      @commitments.each do |cm|
        report cm.inspect
      end
    end
  end
end
