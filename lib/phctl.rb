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

    desc "ht_items FILENAME", "Add HT Items"
    def ht_items(filename)
      Jobs::Load::HtItems.perform_async(filename)
    end

    desc "concordance DATE", "Load concordance deltas for the given date"
    def concordance(date)
      Jobs::Load::Concordance.perform_async(date)
    end

    desc "cluster_file FILENAME", "Add a whole file of clusters in JSON format."
    def cluster_file(filename)
      Jobs::Load::ClusterFile.perform_async(filename)
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
      Jobs::SharedPrintOps::Update.perform_async(infile)
    end

    desc "replace INFILE", "Replace commitments based on provided records"
    def replace(infile)
      Jobs::SharedPrintOps::Replace.perform_async(infile)
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
      Jobs::Report::CostReport.perform_async(options[:organization], options[:target_cost])
    end

    desc "estimate OCN_FILE", "Run an estimate"
    def estimate(ocn_file)
      Jobs::Report::Estimate.perform_async(ocn_file)
    end

    desc "member-counts COST_RPT_FREQ_FILE OUTPUT_DIR", "Calculate member counts"
    def member_counts(cost_rpt_freq_file, output_dir)
      Jobs::Report::MemberCounts.perform_async(cost_rpt_freq_file, output_dir)
    end

    desc "etas-overlap ORGANIZATON", "Run an ETAS overlap report"
    def etas_overlap(org = nil)
      Jobs::Report::EtasOverlap.perform_async(org)
    end

    desc "eligible-commitments OCNS", "Find eligible commitments"
    def eligible_commitments(*ocns)
      Jobs::Report::EligibleCommitments.perform_async(ocns)
    end

    desc "uncommitted-holdings", "Find holdings without commitments"
    option :all, type: :boolean, default: false
    option :verbose, type: :boolean, default: false
    option :organization, type: :array, default: []
    option :ocn, type: :array, default: []
    option :noop, type: :boolean, default: false
    def uncommitted_holdings
      options[:ocn] = options[:ocn].map(&:to_i)
      Jobs::Report::UncommittedHoldings.perform_async(**options)
    end

    # E.g. phctl report rare-uncommitted-counts --max_sp_h 2 --max_h 1
    desc "rare-uncommitted-counts", "Get counts of rare holdings"
    option :max_h, type: :numeric, default: nil
    option :max_sp_h, type: :numeric, default: nil
    option :non_sp_h_count, type: :numeric, default: nil
    option :commitment_count, type: :numeric, default: 0
    option :organization, type: :string, default: nil
    def rare_uncommitted_counts
      Jobs::Report::RareUncommittedCounts.perform_async(**options)
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
  end
end
