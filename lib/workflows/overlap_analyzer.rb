module Workflows
  class OverlapAnalyzer < Workflows::Solr::Analyzer
    attr_reader :input, :report_record_class, :organization, :holdings_scope

    def initialize(input, report_record_class:, organization: nil, holdings_scope: {})
      @input = input
      @organization = organization
      @holdings_scope = holdings_scope
      @report_record_class = MapReduce.to_class(report_record_class)
    end

    def run
      output = input + ".overlap.tsv"

      File.open(output, "w") do |output|
        @output = output

        records_from_file(input, **holdings_scope).each do |record|
          analyze_cluster(record.cluster)
        end
      end
    end

    def analyze_cluster(cluster)
      start = Time.now
      Services.logger.debug("Processing overlaps for #{cluster.ocns}")
      holdings_matched = write_overlaps(cluster)
      write_records_for_unmatched_holdings(cluster, holdings_matched)
      elapsed = Time.now - start
      if Time.now - start > 1
        Services.logger.warn("Slow record: #{cluster.ocns}: #{elapsed} secs")
      end
    end

    def write_overlaps(cluster)
      holdings_matched = Set.new
      # if organization is nil - gets overlap for all orgs
      Overlap::ClusterOverlap.new(cluster, organization).each do |org_item_overlap|
        next if org_item_overlap.matching_holdings.none?

        output.puts(report_record_class.new(organization: org_item_overlap.org, holdings: org_item_overlap.matching_holdings, ht_item: org_item_overlap.ht_item))

        org_item_overlap.matching_holdings.each do |holding|
          holdings_matched << holding
        end
      end
      holdings_matched
    end

    def write_records_for_unmatched_holdings(cluster, holdings_matched)
      records_written = Set.new
      missed_holdings(cluster, holdings_matched).each do |holding|
        report_record = report_record_class.new(organization: holding.organization, holdings: [holding])
        next if records_written.include? report_record.to_s

        records_written << report_record.to_s
        output.puts(report_record)
      end
    end

    # Holdings with org/local_id not found in holdings_matched
    #
    # @param cluster [Cluster]
    # @param holdings_matched [Set] set of holdings that did match an item
    def missed_holdings(cluster, holdings_matched, relevant_holdings: cluster.holdings)
      org_local_ids = Set.new(holdings_matched.map { |h| [h.organization, h.local_id] })

      relevant_holdings.reject do |h|
        org_local_ids.include? [h.organization, h.local_id]
      end || []
    end

    private

    attr_reader :output, :milemarker
  end
end
