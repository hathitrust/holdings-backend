# frozen_string_literal: true

require "services"
require "reports/uncommitted_holdings_record"
require "overlap/holding_commitment"

module Reports
  # Get holdings from spm clusters where there are items & holdings but no active commitments.
  # Allow to optionally filter by OCN(s) and/or organization(s).
  # "I want to know which items in HTDL lack commitments,
  #  so I can seek new titles to secure commitments on"
  # Invoke via bin/reports/compile_uncommitted_holdings.rb
  class UncommittedHoldings
    def initialize(all: false, ocn: [], organization: [], verbose: false, noop: false)
      # Get query criteria:
      @all = all
      @ocn = ocn
      @organization = organization
      raise ArgumentError if no_criteria?

      # Get any non-query flags.
      @verbose = verbose
      @noop = noop
      @query = {"ht_items.0": {"$exists": 1}, "holdings.0": {"$exists": 1}}
    end

    def no_criteria?
      !@all && @ocn.empty? && @organization.empty?
    end

    def run(output_filename = report_file)
      File.open(output_filename, "w") do |fh|
        fh.puts header.join("\t")
        records.each { |record| fh.puts record.to_s }
      end
    end

    def records
      return to_enum(__method__) unless block_given?
      refine_query
      warn "Query: #{@query}" if @verbose

      if @noop
        warn "Returning before executing query, because @noop==true" if @verbose
        return
      end

      Cluster.where(@query).no_timeout.each do |cluster|
        next unless cluster.format == "spm"
        next if cluster.commitments.reject(&:deprecated?).any?
        cluster.holdings.each do |holding|
          yield Reports::UncommittedHoldingsRecord.new(holding)
        end
      end
    end

    def refine_query
      unless @all # @all == true means no more query building
        if @ocn.any?
          @query["ocns"] = {"$in": @ocn}
        end
        if @organization.any?
          @query["holdings.organization"] = {"$in": @organization}
        end
      end
    end

    def header
      ["organization", "oclc_sym", "ocn", "local_id"]
    end

    private

    def report_file
      FileUtils.mkdir_p(Settings.shared_print_report_path)
      iso_stamp = Time.now.strftime("%Y%m%d-%H%M%S")
      organization = @organization.join("_") || "all"
      File.join(Settings.shared_print_report_path, "uncommitted_holdings_#{organization}_#{iso_stamp}.txt")
    end
  end
end
