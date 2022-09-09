require "thor"
require "sidekiq_jobs"

$LOAD_PATH.unshift(File.dirname(__FILE__))

# This can be started locally with
# `docker-compose run --rm dev bundle exec bin/phctl.rb <command>`
# or on the cluster with
# `ht_tanka/environments/holdings/jobs/run_generic_job.sh bin/phctl.rb <command>`
module PHCTL
  class Load < Thor
    desc "commitments FILENAME", "Add shared print commitments"
    def commitments(filename)
      Jobs::Load::Commitments.perform_async(filename)
    end

    desc "ht-items FILENAME", "Add HT Items"
    def ht_items(filename)
      Jobs::Load::HtItems.perform_async(filename)
    end

    desc "concordance DATE", "Load concordance deltas for the given date"
    def concordance(date)
      Jobs::Load::Concordance.perform_async(date)
    end

    desc "cluster-file FILENAME", "Add a whole file of clusters in JSON format."
    def cluster_file(filename)
      Jobs::Load::ClusterFile.perform_async(filename)
    end

    desc "holdings FILENAME", "Loads scrubbed holdings."
    def holdings(filename)
      Jobs::Load::Holdings.perform_async(filename)
    end
  end

  class Cleanup < Thor
    desc "holdings INST DATE", "Deletes holdings for INST that were last updated prior to DATE."
    def holdings(inst, date)
      Jobs::Cleanup::Holdings.perform_async(inst, date)
    end
  end

  class Concordance < Thor
    desc "validate INFILE OUTFILE", "Validate a concordance file"
    def validate(infile, outfile)
      Jobs::Concordance::Validate.perform_async(infile, outfile)
    end

    desc "delta", "Computes deltas in default concordance directory"
    def delta(old, new)
      Jobs::Concordance::Delta.perform_async(old, new)
    end
  end

  class SharedPrintOps < Thor
    desc "update INFILE", "Update commitments based on provided records"
    def update(infile)
      Jobs::Common.perform_async("SharedPrint::Updater", options, infile)
    end

    desc "replace INFILE", "Replace commitments based on provided records"
    def replace(infile)
      Jobs::Common.perform_async("SharedPrint::Replacer", options, infile)
    end

    desc "deprecate INFILE", "Deprecate commitments based on provided records"
    option :verbose, type: :boolean, default: false
    def deprecate(*infile)
      Jobs::SharedPrintOps::Deprecate.perform_async(options[:verbose], [*infile])
    end
  end

  class Report < Thor
    desc "costreport (--organization ORG) (--target_cost COST)", "Run a cost report"
    option :organization, type: :string, default: nil
    option :target_cost, type: :numeric, default: nil
    def costreport
      Jobs::Common.perform_async("Reports::CostReport", options)
    end

    desc "estimate OCN_FILE", "Run an estimate"
    def estimate(ocn_file)
      Jobs::Common.perform_async("Reports::Estimate", options, ocn_file)
    end

    desc "member-counts COST_RPT_FREQ_FILE OUTPUT_DIR", "Calculate member counts"
    def member_counts(cost_rpt_freq_file, output_dir)
      Jobs::Common.perform_async("Reports::MemberCounts", options, cost_rpt_freq_file, output_dir)
    end

    desc "etas-overlap ORGANIZATON", "Run an ETAS overlap report"
    def etas_overlap(org = nil)
      # TODO rename report class
      Jobs::Common.perform_async("Reports::EtasOrganizationOverlapReport", options, org)
    end

    desc "eligible-commitments OCNS", "Find eligible commitments"
    def eligible_commitments(*ocns)
      # TODO rename report class
      Jobs::Common.perform_async("Reports::CommitmentReplacements", options, ocns)
    end

    desc "uncommitted-holdings", "Find holdings without commitments"
    option :all, type: :boolean, default: false
    option :verbose, type: :boolean, default: false
    option :organization, type: :array, default: []
    option :ocn, type: :array, default: []
    option :noop, type: :boolean, default: false
    def uncommitted_holdings
      options[:ocn] = options[:ocn].map(&:to_i)
      Jobs::Common.perform_async("Reports::UncommittedHoldings", options)
    end

    # E.g. phctl report rare-uncommitted-counts --max_sp_h 2 --max_h 1
    desc "rare-uncommitted-counts", "Get counts of rare holdings"
    option :max_h, type: :numeric, default: nil
    option :max_sp_h, type: :numeric, default: nil
    option :non_sp_h_count, type: :numeric, default: nil
    option :commitment_count, type: :numeric, default: 0
    option :organization, type: :string, default: nil
    def rare_uncommitted_counts
      # TODO rename command or report class
      Jobs::Common.perform_async("Reports::RareUncommitted", options)
    end
  end

  class PHCTL < Thor
    desc "members", "Prints all current members"
    def members
      puts DataSources::HTOrganizations.new.members.keys
    end

    # standard:disable Lint/Debugger
    desc "pry", "Opens a pry-shell with environment loaded"
    def pry
      require "pry"
      binding.pry
    end
    # standard:enable Lint/Debugger

    # report
    desc "report", "Generate a report"
    subcommand "report", Report

    desc "load <clusterable> <args>", "Load clusterable records"
    subcommand "load", Load

    desc "concordance", "Validate or validate and compute deltas"
    subcommand "concordance", Concordance

    desc "sp", "Shared print operations"
    subcommand "sp", SharedPrintOps

    desc "cleanup", "Cleanup operations"
    subcommand "cleanup", Cleanup
  end
end
