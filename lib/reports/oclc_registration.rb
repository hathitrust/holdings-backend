# frozen_string_literal: true

require "services"
require "shared_print/finder"
require "utils/tsv_reader"

module Reports
  # Runs a report for an organization, outputting all of their
  # shared print commitments in an OCLC Registration-like format.
  class OCLCRegistration
    attr_reader :output_file
    def initialize(organization)
      @organization = organization
      @outd = Settings.oclc_registration_report_path
      @collection_id_map_path = Settings.oclc_collection_id_map_path
      validate!
      @collection_memo = {}
    end

    # Get all the commitments for @organization and ouptut to file.
    def run
      # Get commitments
      finder = SharedPrint::Finder.new(organization: [@organization])
      # Set up path for output
      date = Time.new.strftime("%Y%m%d")
      outp = File.join(@outd, "oclc_registration_#{@organization}_#{date}.tsv")
      # Open file and write header & formatted commitments
      File.open(outp, "w") do |outf|
        outf.puts hed
        finder.commitments.each do |commitment|
          outf.puts(fmt(commitment))
        end
      end
      @output_file = outp
    end

    # Generate report header.
    def hed
      [
        "local_oclc", # com.ocn
        "LSN", # con.local_id
        "Institution symbol 852$a", # com.oclc_sym
        "Collection ID", # look up
        "Action Note 583$a", # hard "committed to retain"
        "Action date 583$c", # com.committed_date
        "Expiration date 583$d" # hard "20421231"
      ].join("\t")
    end

    # Format a commitment for the report.
    def fmt(com)
      [
        com.ocn,
        com.local_id,
        com.oclc_sym,
        collection_id(com.oclc_sym),
        "committed to retain",
        com.committed_date,
        "20421231"
      ].join("\t")
    end

    # Memoize the oclc_collection_id file into a {oclc_sym => collection_id} hash,
    # and look up oclc_sym in that hash.
    def collection_id(oclc_sym)
      if @collection_memo.empty?
        Utils::TSVReader.new(@collection_id_map_path).run do |rec|
          @collection_memo[rec[:oclc_sym]] = rec[:collection_id]
        end
      end
      if @collection_memo[oclc_sym].nil?
        raise KeyError,
          "No collection_id for oclc_sym \"#{oclc_sym}\"" \
          "in #{@collection_id_map_path}"
      end
      @collection_memo[oclc_sym]
    end

    private

    def validate!
      raise "Organization not set" if @organization.nil?
      # Require that a path for a dir for output files be set.
      raise "Settings.oclc_registration_report_path not set" if @outd.nil?
      # Require that a path to a file with oclc_collection mapping be set.
      raise "Settings.oclc_collection_id_map not set" if @collection_id_map_path.nil?
    end
  end
end
