# frozen_string_literal: true

require "overlap/ht_item_overlap"
require "services"
require "tmpdir"
require "reports/cost_report"
require "solr/cursorstream"
require "solr_batch"

module Reports
  # Generate IC estimate from a list of OCNS
  class Estimate
    attr_reader :ocns, :ocn_file, :h_share_total, :num_ocns_matched,
      :num_items_matched, :num_items_pd, :num_items_ic,
      :marker, :solr_query_size, :mariadb_query_size

    def initialize(ocn_file = nil, solr_query_size: 500, mariadb_query_size: 100, batch_size: 1000)
      @ocn_file = ocn_file
      @h_share_total = 0
      @num_ocns_matched = 0
      @num_items_matched = 0
      @num_items_pd = 0
      @num_items_ic = 0
      @solr_query_size = solr_query_size
      @mariadb_query_size = mariadb_query_size
      @marker = Milemarker.new(batch_size: batch_size)
      if Settings.estimates_path.nil?
        raise ArgumentError, "Settings.estimates_path must be set."
      end
    end

    def cost_report
      @cost_report ||= CostReport.new
    end

    # duplicated with CostReportWorkflow, but different base path / key
    def default_working_directory
      work_base = File.join(Settings.estimates_path, "work")
      FileUtils.mkdir_p(work_base)
      Dir.mktmpdir("estimate_", work_base)
    end

    def run(output_filename = report_file(ocn_file))
      Services.logger.info "Target Cost: #{cost_report.target_cost}"
      Services.logger.info "Cost per volume: #{cost_report.cost_per_volume}"
      Services.logger.info "Starting #{Pathname.new(__FILE__).basename}. Batches of #{ppnum marker.batch_size}"

      Services.logger.debug("Loading OCNs")
      @ocns = File.open(ocn_file).map(&:to_i).to_set
      Services.logger.debug("#{@ocns.count} unique OCNs")

      dump_solr_records(ocns)
      find_matching_ocns

      File.open(output_filename, "w") do |fh|
        fh.puts [
          "Total Estimated IC Cost: $#{total_estimated_ic_cost.round(2)}",
          "In all, we received #{ocns.count} distinct OCLC numbers.",
          "Of those distinct OCLC numbers, #{num_ocns_matched} (#{pct_ocns_matched.round(1)}%) match items in",
          "HathiTrust, corresponding to #{num_items_matched} HathiTrust items.",
          "Of those items, #{num_items_pd} (#{pct_items_pd.round(1)}%) are in the public domain,",
          "#{num_items_ic} (#{pct_items_ic.round(1)}%) are in copyright."
        ].join("\n")
      end
    end

    def dump_solr_records(ocns)
      core_url = ENV["SOLR_URL"]
      milemarker = Milemarker.new(batch_size: 1000, name: "get solr records")
      milemarker.logger = Services.logger
      ocns_seen = Set.new
      solr_records_seen = Set.new

      File.open(allrecords_ndj, "w") do |out|
        # first pass: dump solr records
        ocns.each_slice(solr_query_size) do |ocn_batch|
          # TODO refactor duplication
          Solr::CursorStream.new(url: core_url) do |s|
            s.fields = %w[ht_json id oclc oclc_search title format]
            s.filters = ["oclc_search:(#{ocn_batch.join(" ")})"]
            s.batch_size = 5000
          end.each do |record|
            next if solr_records_seen.include?(record["id"])
            solr_records_seen.add(record["id"])
            ocns_seen.merge(record["oclc_search"].map(&:to_i))
            out.puts record.to_json
            milemarker.increment_and_log_batch_line
          end
        end
        milemarker.log_final_line
      end

      @num_ocns_matched = ocns.to_set.intersection(ocns_seen).count
    end

    def find_matching_ocns(record_file = allrecords_ndj)
      # second pass: for each chunk of solr records, fetch holdings in a batch
      # & count matching items
      milemarker = Milemarker.new(batch_size: 1000, name: "compile estimate")
      milemarker.logger = Services.logger
      File.open(record_file).each_slice(mariadb_query_size) do |lines|
        SolrBatch.new(lines).records.each do |record|
          # make sure htitems are parsed out
          record.ht_items
          count_matching_items(record.cluster)
          milemarker.increment_and_log_batch_line
        end
      end
      milemarker.log_final_line
    end

    def allrecords_ndj
      @allrecords_ndj ||= File.join(default_working_directory, "allrecords.ndj")
    end

    def pct_ocns_matched
      @num_ocns_matched.to_f / @ocns.uniq.count * 100
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
        Services.logger.debug "running total: num_items_matched=#{num_items_matched} num_items_pd=#{num_items_pd} num_items_ic=#{num_items_ic} h_share_total=#{h_share_total}"
      end
    end

    def report_file(ocn_file)
      FileUtils.mkdir_p(Settings.estimates_path)
      File.join(Settings.estimates_path, File.basename(ocn_file, ".txt") + "-estimate-#{Date.today}.txt")
    end
  end
end
