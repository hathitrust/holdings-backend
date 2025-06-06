# frozen_string_literal: true

require "services"
require "tmpdir"
require "overlap/ht_item_overlap"
require "reports/cost_report"
require "solr_batch"
require "workflows/solr"

module Workflows
  # Generate IC estimate from a list of OCNS
  module Estimate
    class DataSource < Workflows::Solr::DataSource
      def initialize(ocn_file:,
        ocns_per_solr_query: Settings.solr_data_source.ocns_per_solr_query)
        @ocn_file = ocn_file
        @ocns_per_solr_query = ocns_per_solr_query
        @ocns_seen = Set.new
        @solr_records_seen = Set.new
      end

      def dump_records(output_filename)
        ocns = load_ocns

        with_milemarked_output(output_filename) do |output_record|
          # first pass: dump solr records
          ocns.each_slice(ocns_per_solr_query) do |ocn_slice|
            cursorstream do |s|
              s.filters = ["oclc_search:(#{ocn_slice.join(" ")})"]
            end.each do |record|
              next if @solr_records_seen.include?(record["id"])
              @solr_records_seen.add(record["id"])
              @ocns_seen.merge(record["oclc_search"].map(&:to_i))
              output_record.call(record)
            end
          end
        end

        record_ocn_count(ocns, File.dirname(output_filename))
      end

      private

      def record_ocn_count(ocns, outdir)
        File.open(File.join(outdir, "ocn_count.estimate.json"), "w") do |f|
          f.puts(
            {
              "ocns_total" => ocns.count,
              "ocns_matched" => ocns.intersection(@ocns_seen).count
            }.to_json
          )
        end
      end

      def load_ocns
        Services.logger.debug("Loading OCNs")
        File.open(ocn_file).map(&:to_i).to_set.tap do |ocns|
          Services.logger.debug("#{ocns.count} unique OCNs")
        end
      end

      attr_reader :ocn_file, :ocns_per_solr_query
    end

    class Analyzer < Workflows::Solr::Analyzer
      attr_reader :output

      def initialize(input)
        @input = input

        @num_items_matched = 0
        @num_items_ic = 0
        @num_items_pd = 0
        @h_share_total = 0
      end

      def run
        records_from_file(input).each do |record|
          count_matching_items(record.cluster)
        end
        save_output
      end

      private

      attr_reader :input

      def save_output
        output = input + ".estimate.json"

        File.open(output, "w") do |f|
          f.puts({
            "items_matched" => @num_items_matched,
            "items_ic" => @num_items_ic,
            "items_pd" => @num_items_pd,
            "h_share" => @h_share_total
          }.to_json)
        end
      end

      def count_matching_items(cluster)
        @num_items_matched += cluster.ht_items.count
        cluster.ht_items.each do |ht_item|
          Services.logger.debug("Estimate: matched htitem item_id=#{ht_item.item_id} rights=#{ht_item.rights}")
          if Clusterable::HtItem::IC_RIGHTS_CODES.include?(ht_item.rights)
            @num_items_ic += 1
          else
            @num_items_pd += 1
            next
          end

          overlap = Overlap::HtItemOverlap.new(ht_item)
          # Insert a placeholder for the prospective member
          overlap.matching_members << "prospective_member"
          @h_share_total += overlap.h_share("prospective_member")
          Services.logger.debug "running total: num_items_matched=#{@num_items_matched} num_items_pd=#{@num_items_pd} num_items_ic=#{@num_items_ic} h_share_total=#{@h_share_total}"
        end
      end
    end

    class Writer
      def initialize(working_directory:, ocn_file:)
        @working_directory = working_directory
        @ocn_file = ocn_file

        @num_ocns_matched = 0
        @total_ocns = 0
        @num_items_pd = 0
        @num_items_ic = 0
        @num_items_matched = 0
        @h_share_total = 0
      end

      def cost_report
        @cost_report ||= Reports::CostReport.new
      end

      def run(output_filename = report_file(ocn_file))
        Services.logger.info "Target Cost: #{cost_report.target_cost}"
        Services.logger.info "Cost per volume: #{cost_report.cost_per_volume}"

        sum_counts

        File.open(output_filename, "w") do |fh|
          fh.puts [
            "Total Estimated IC Cost: $#{sprintf("%0.2f", total_estimated_ic_cost)}",
            "In all, we received #{total_ocns} distinct OCLC numbers.",
            "Of those distinct OCLC numbers, #{num_ocns_matched} (#{pct_ocns_matched.round(1)}%) match items in",
            "HathiTrust, corresponding to #{num_items_matched} HathiTrust items.",
            "Of those items, #{num_items_pd} (#{pct_items_pd.round(1)}%) are in the public domain,",
            "#{num_items_ic} (#{pct_items_ic.round(1)}%) are in copyright."
          ].join("\n")
        end
      end

      def pct_ocns_matched
        @num_ocns_matched / @total_ocns.to_f * 100
      end

      def pct_items_pd
        @num_items_pd / @num_items_matched.to_f * 100
      end

      def pct_items_ic
        @num_items_ic / @num_items_matched.to_f * 100
      end

      def total_estimated_ic_cost
        @h_share_total * cost_report.cost_per_volume
      end

      private

      attr_reader :total_ocns, :num_items_pd, :num_items_ic,
        :num_items_matched, :num_ocns_matched, :h_share_total,
        :ocn_file, :working_directory

      def sum_counts
        Dir.glob(File.join(working_directory, "*.estimate.json")).each do |f|
          partial_counts = JSON.parse(File.read(f))

          @num_ocns_matched += partial_counts.fetch("ocns_matched", 0)
          @total_ocns += partial_counts.fetch("ocns_total", 0)
          @num_items_pd += partial_counts.fetch("items_pd", 0)
          @num_items_ic += partial_counts.fetch("items_ic", 0)
          @num_items_matched += partial_counts.fetch("items_matched", 0)
          @h_share_total += partial_counts.fetch("h_share", 0)
        end
      end

      def report_file(ocn_file)
        FileUtils.mkdir_p(Settings.estimates_path)
        File.join(Settings.estimates_path, File.basename(ocn_file, ".txt") + "-estimate-#{Date.today}.txt")
      end
    end
  end
end
