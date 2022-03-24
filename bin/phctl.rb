#!/usr/bin/env ruby
# frozen_string_literal: true

require "thor"
require "pry"
require "services"
require "loader/file_loader"
require "loader/ht_item_loader"
require "loader/shared_print_loader"
require "reports/commitment_replacements"
require "reports/etas_organization_overlap_report"
require "reports/uncommitted_holdings"
$LOAD_PATH.unshift(File.dirname(__FILE__))
require "concordance_processing"
require "ocn_concordance_diffs"
require "report/compile_cost_reports"
require "report/compile_estimated_IC_costs"
require "report/compile_member_counts_report"
require "shared_print/updater"
require "shared_print/replacer"
require "shared_print/deprecator"

Services.mongo!

# This can be started locally with
# `docker-compose run --rm dev bundle exec bin/phctl.rb <command>`
# or on the cluster with 
# `ht_tanka/environments/holdings/jobs/run_generic_job.sh bin/phctl.rb <command>`
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
      OCNConcordanceDiffs.new(Date.parse(date)).load
    end
  end

  class Concordance < Thor
  
    desc "validate INFILE OUTFILE",  "Validate a concordance file"
    def validate(infile, outfile)
      ConcordanceProcessing.new.validate(infile, outfile)
    end

    desc "delta", "Computes deltas in default concordance directory"
    def delta(old, new)
      ConcordanceProcessing.new.delta(old, new)
    end 
  end

  class SharedPrintOps < Thor
    desc "update INFILE", "Update commitments based on provided records"
    def update(infile)
      SharedPrint::Updater.new(infile).run
    end

    desc "replace INFILE", "Replace commitments based on provided records"
    def replace(infile)
      SharedPrint::Replacer.new(infile).run
    end

    desc "deprecate INFILE", "Decprecate commitments based on provided records"
    option :verbose, :type => :boolean, :default => false
    def deprecate(infile)
      SharedPrint::Deprecator.new(verbose: options[:verbose]).run(infile)
    end
  end

  class Report < Thor
    desc "costreport ORG", "Run a cost report"
    def costreport(org=nil)
      CompileCostReport.new.run(org)
    end

    desc "estimate OCN_FILE", "Run an estimate"
    def estimate(ocn_file)
      CompileEstimate.new.run(ocn_file)
    end

    desc "member-counts COST_RPT_FREQ_FILE OUTPUT_DIR", "Calculate member counts"
    def member_counts(cost_rpt_freq_file, output_dir)
      CompileMemberCounts.new.run(cost_rpt_freq_file, output_dir)
    end
  
    desc "etas-overlap ORGANIZATON", "Run an ETAS overlap report"
    def etas_overlap(org=nil)
      rpt = Reports::EtasOrganizationOverlapReport.new(org)
      rpt.run
      rpt.move_reports_to_remote
    end

    desc "eligible-commitments OCNS", "Find eligible commitments"
    def eligible_commitments(*ocns)
      report = Reports::CommitmentReplacements.new
      puts report.header.join("\t")
      report.for_ocns(ocns.map(&:to_i)) do |row|
        puts row.join("\t")
      end
    end

    desc "uncommitted-holdings", "Find holdings without commitments"
    option :all, :type => :boolean, :default => false
    option :verbose, :type => :boolean, :default => false
    option :organization, :type => :array, :default => []
    option :ocn, :type => :array, :default => []
    option :noop, :type => :boolean, :default =>  false
    def uncommitted_holdings
      options[:ocn] = options[:ocn].map(&:to_i)
      report = Reports::UncommittedHoldings.new(all: options[:all],
                                                ocn: options[:ocn],
                                                organization: options[:organization],
                                                verbose: options[:verbose],
                                                noop: options[:noop])
      puts report.header.join("\t")
      report.run  { |record| puts record.to_s }
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

    desc "sp", "Shared print operations"
    subcommand "sp", SharedPrintOps
  end

end

PHCTL::PHCTL.start(ARGV)
