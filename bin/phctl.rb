#!/usr/bin/env ruby
# frozen_string_literal: true

require "thor"
require "pry"
require "services"
require "loader/file_loader"
require "loader/shared_print_loader"

Services.mongo!

module PHCTL
  class Load < Thor
    desc "commitments FILENAME", "Add shared print commitments"
    def commitments(filename)
      Services.logger.info "Loading Shared Print Commitments: #{filename}"
      Loader::FileLoader.new(batch_loader: Loader::SharedPrintLoader.new).load(filename) 
    end

    desc "ht_items FILENAME", "Add HT Items"
    def ht_items(filename)
      Services.logger.info "Updating HT Items."
      Loader::FileLoader.new(batch_loader: Loader::HtItemLoader.new).load(filename)
    end

    desc "concordance DATE", "Load concordance deltas for the given date"
    def concordance(date)
      require "ocn_concordance_diffs"
      OCNConcordanceDiffs.new(Date.parse(date)).load
    end
  end

  class Concordance < Thor
  
    desc "validate INFILE OUTFILE",  "Validate a concordance file"
    def validate(infile, outfile)
      require_relative "concordance_validation/validate.rb"
      main(infile, outfile)
    end

    desc "validate-and-delta", "Validates and computes deltas in default concordance directory"
    def validate_and_delta
      require_relative "concordance_validation/validate_and_delta.rb"
      main
    end 
  end


  class Report < Thor
    desc "costreport ORG", "Run a cost report"
    def costreport(org=nil)
      require_relative "reports/compile_cost_reports.rb"
      main(org)
    end

    desc "estimate OCN_FILE", "Run an estimate"
    def estimate(ocn_file)
      require_relative "reports/compile_estimated_IC_costs.rb"
      main(ocn_file)
    end

    desc "eligible-commitments OCNS", "Find eligible commitments"
    def eligible_commitments(*ocns)
      require "reports/eligible_commitments"
      report = Reports::EligibleCommitments.new
      puts report.header.join("\t")
      report.for_ocns(ocns.map(&:to_i)) do |row|
        puts row
      end
    end

    desc "member-counts COST_RPT_FREQ_FILE OUTPUT_DIR", "Calculate member counts"
    def member_counts(cost_rpt_freq_file, output_dir)
      require_relative "reports/compile_member_counts_report.rb"
      main(cost_rpt_freq_file, output_dir)
    end
  
    desc "etas-overlap ORGANIZATON", "Run an ETAS overlap report"
    def etas_overlap(org=nil)
      require "reports/etas_organization_overlap_report"
      rpt = Reports::EtasOrganizationOverlapReport.new(org)
      rpt.run
      rpt.move_reports_to_remote
    end
  end
  
  class PHCTL < Thor
    desc "members", "Prints all current members"
    def members
      puts DataSources::HTOrganizations.new.members.keys
    end

    desc "pry", "Opens a pry-shell with environment loaded"
    def pry
      binding.pry
    end
    
    # report
    desc "report", "Generate a report"
    subcommand "report", Report

    desc "load <clusterable> <args>", "Load clusterable records"
    subcommand "load", Load

    desc "concordance", "Validate or validate and compute deltas"
    subcommand "concordance", Concordance
  end

end

PHCTL::PHCTL.start(ARGV)
