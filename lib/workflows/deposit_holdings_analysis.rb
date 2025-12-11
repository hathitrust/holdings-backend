require "workflows/solr"
require "clusterable/ht_item"
require "frequency_table"

module Workflows
  module DepositHoldingsAnalysis
    class DataSource < Workflows::Solr::DataSource
      def dump_records(output_filename)
        with_milemarked_output(output_filename) do |output_record|
          cursorstream do |s|
            s.filters = filters
          end.each do |record|
            output_record.call(record)
          end
        end
      end

      def filters
        ic_rights = (Clusterable::HtItem::IC_RIGHTS_CODES + ["icus"]).join(" ")
        ["ht_rightscode:(#{ic_rights})"]
      end
    end

    class Analyzer < Workflows::Solr::Analyzer
      attr_reader :solr_records, :output_file

      def initialize(solr_records,
        output: solr_records + ".holdings_analysis.tsv")
        @solr_records = solr_records
        @output_file = output
      end

      def run
        log = Services.logger

        # Services.holdings_db.loggers << Logger.new($stdout)
        log.info("starting report generation from #{solr_records}")

        File.open(output_file, "w") do |fh|
          records_from_file(solr_records).each do |record|
            record.ht_items.select { |item| item.ic? || item.rights == "icus" }.each do |ht_item|
              fh.puts(report_for(ht_item).join("\t"))
            end
          end
        end

        log.info("done w analysis, writing to #{output_file}")
      end

      def report_for(ht_item)
        status = analyze(ht_item)
        inst_id = ht_item.billing_entity
        mapto_inst_id = Services.ht_organizations[inst_id].mapto_inst_id
        mapped_status = analyze_mapped(ht_item, mapto_inst_id)

        [
          ht_item.item_id,
          ht_item.rights,
          ht_item.billing_entity,
          status,
          mapto_inst_id,
          mapped_status
        ]
      end

      def analyze(ht_item)
        overlap_status(ht_item, [ht_item.billing_entity])
      end

      def analyze_mapped(ht_item, mapto_inst_id)
        # Find all the inst ids that map to the same inst id as the billing entity
        mapto_instids = Services.ht_organizations.mapto(mapto_inst_id).map(&:inst_id)

        overlap_status(ht_item, mapto_instids)
      end

      private

      def overlap_status(ht_item, orgs)
        return :no_ocn if ht_item.ocns.empty?

        analyze_overlap_records(
                                orgs.map do |mapped_org|
                                  Overlap::ClusterOverlap.overlap_record(mapped_org, ht_item)
                                end
                              )
      end

      def analyze_overlap_records(overlap_records)
        return :not_held if overlap_records.map(&:matching_count).all?(&:zero?)
        return :held if overlap_records.sum(&:current_holding_count).positive?
        return :lost_missing if overlap_records.sum(&:lm_count).positive?
        return :withdrawn if overlap_records.sum(&:wd_count).positive?

        :unknown
      end
    end

    # Merges output files from Analyzer together and outputs result
    # TODO mostly duplicated from overlap report output; extract common stuff?
    class Writer
      def initialize(working_directory:)
        @working_directory = working_directory
        @report_path = Settings.overlap_reports_path
        Dir.mkdir(@report_path) unless File.exist?(@report_path)
      end

      def run
        gzip_report
      end

      def header
        [
          "item_id",
          "rights",
          "billing_entity",
          "holdings_status",
          "mapto_inst_id",
          "mapped_holdings_status"
        ].join("\t")
      end

      def report_filename
        return @report_filename if @report_filename

        @report_filename = "deposit_holdings_analysis_#{Date.today}.tsv.gz"
      end

      private

      attr_reader :report_path, :working_directory

      def report_gz_path
        File.join(report_path, report_filename)
      end

      def gzip_report
        Zlib::GzipWriter.open(report_gz_path) do |gz|
          gz.puts(header)
          Dir.glob(File.join(working_directory, "*.tsv")).each do |rpt|
            File.open(rpt) do |file|
              while (chunk = file.read(16 * 1024))
                gz.write(chunk)
              end
            end
          end
        end
      end
    end
  end
end
