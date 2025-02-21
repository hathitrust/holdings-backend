require "thor"
require "sidekiq_jobs"

$LOAD_PATH.unshift(File.dirname(__FILE__))

# This can be started locally with
# `docker-compose run --rm dev bundle exec bin/phctl.rb <command>`
# or on the cluster with
# `ht_tanka/environments/holdings/jobs/run_generic_job.sh bin/phctl.rb <command>`
module PHCTL
  class JobCommand < Thor
    no_commands do
      def run_job(klass, *args, **kwargs)
        if parent_options[:inline]
          klass.new.perform(*args, **kwargs)
        else
          klass.perform_async(*args, **kwargs)
        end
      end

      def run_common_job(klass, options, *args, **kwargs)
        options.delete(:inline)
        run_job(Jobs::Common, klass.to_s, options.to_hash, *args, **kwargs)
      end
    end
  end

  class Load < JobCommand
    desc "commitments FILENAME", "Add shared print commitments"
    def commitments(filename)
      run_job(Jobs::Load::Commitments, filename)
    end

    desc "ht-items FILENAME", "Add HT Items"
    def ht_items(filename)
      run_job(Jobs::Load::HtItems, filename)
    end

    desc "concordance DATE", "Load concordance deltas for the given date"
    def concordance(date)
      run_job(Jobs::Load::Concordance, date)
    end

    desc "cluster-file FILENAME", "Add a whole file of clusters in JSON format."
    def cluster_file(filename)
      run_job(Jobs::Load::ClusterFile, filename)
    end

    desc "holdings FILENAME", "Loads scrubbed holdings."
    def holdings(filename)
      run_job(Jobs::Load::Holdings, filename)
    end
  end

  class Cleanup < JobCommand
    desc "holdings INST DATE", "Deletes holdings for INST that were last updated prior to DATE."
    def holdings(inst, date)
      run_job(Jobs::Cleanup::Holdings, inst, date)
    end

    desc "duplicate_holdings", "Cleans duplicate holdings from all clusters"
    def duplicate_holdings
      CleanupDuplicateHoldings.queue_jobs
    end
  end

  class Concordance < JobCommand
    desc "validate INFILE OUTFILE", "Validate a concordance file"
    def validate(infile, outfile)
      run_job(Jobs::Concordance::Validate, infile, outfile)
    end

    desc "delta", "Computes deltas in default concordance directory"
    def delta(old, new)
      run_job(Jobs::Concordance::Delta, old, new)
    end
  end

  class SharedPrintOps < JobCommand
    desc "update INFILE", "Update commitments based on provided records"
    def update(infile)
      run_common_job(SharedPrint::Updater, options, infile)
    end

    desc "replace INFILE", "Replace commitments based on provided records"
    def replace(infile)
      run_common_job(SharedPrint::Replacer, options, infile)
    end

    desc "deprecate INFILE", "Deprecate commitments based on provided records"
    option :verbose, type: :boolean, default: false
    def deprecate(*infile)
      run_job(Jobs::SharedPrintOps::Deprecate, options[:verbose], [*infile])
    end

    desc "phase3load INFILE", "Load Phase 3 commitments, if valid, from file"
    def phase3load(infile)
      run_common_job(SharedPrint::Phase3Validator, options, infile)
    end
  end

  class Report < JobCommand
    desc "costreport (--organization ORG) (--target_cost COST) (--frequency-table /path/to/table.json) (--precomputed-frequency-table-dir /path/to/tables)", "Run a cost report. If neither --precomputed-frequency-table nor --frequency-table-dir is specified, generate a new frequency table."
    option :organization, type: :string, default: nil
    option :target_cost, type: :numeric, default: nil
    option :precomputed_frequency_table, type: :string, default: nil, desc: "The full path to a .json frequency table to use for the report."
    option :precomputed_frequency_table_dir, type: :string, default: nil, desc: "A directory containing .json frequency tables to sum for this cost report."
    def costreport
      run_common_job(Reports::CostReport, options)
    end

    desc "report frequency-table HT_ITEM_FILE OUTFILE", "Generate a frequency table from (partial) hathifiles data"
    option :ht_item_file, type: :string, desc: "Full path to input tabular 8-column data from hf (htid, bib_num, rights_code, access, bib_fmt, description, collection_code, oclc)"
    option :output_file, type: :string, desc: "Full path to output cost report file"
    def frequency_table
      run_common_job(Reports::FrequencyTableChunk, options, ht_item_file, output_file)
    end

    desc "estimate OCN_FILE", "Run an estimate"
    def estimate(ocn_file)
      run_common_job(Reports::Estimate, options, ocn_file)
    end

    desc "member-counts COST_RPT_FREQ_FILE OUTPUT_DIR", "Calculate member counts"
    def member_counts(cost_rpt_freq_file, output_dir)
      run_common_job(Reports::MemberCounts, options, cost_rpt_freq_file, output_dir)
    end

    desc "etas-overlap ORGANIZATON", "Run an ETAS overlap report"
    def etas_overlap(org = nil)
      # TODO rename report class
      run_common_job(Reports::EtasOrganizationOverlapReport, options, org)
    end

    desc "eligible-commitments OCNS", "Find eligible commitments"
    def eligible_commitments(*ocns)
      # TODO rename report class
      run_common_job(Reports::CommitmentReplacements, options, ocns)
    end

    desc "uncommitted-holdings", "Find holdings without commitments"
    option :all, type: :boolean, default: false
    option :verbose, type: :boolean, default: false
    option :organization, type: :array, default: []
    option :ocn, type: :array, default: []
    option :noop, type: :boolean, default: false
    def uncommitted_holdings
      options[:ocn] = options[:ocn].map(&:to_i)
      run_common_job(Reports::UncommittedHoldings, options)
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
      run_common_job(Reports::RareUncommitted, options)
    end

    desc "oclc-registration ORGANIZATION", "Output all commitments for ORG in OCLC Registration format"
    def oclc_registration(organization)
      run_common_job(Reports::OCLCRegistration, options, organization)
    end

    desc "phase3-oclc-registration ORGANIZATION", "Output all phase 3 commitments for ORG in OCLC Registration format"
    def phase3_oclc_registration(organization)
      run_common_job(Reports::Phase3OCLCRegistration, options, organization)
    end

    desc "organization-holdings-overlap", "Organization-based overlap report that counts overlaps with holdings, commitments and/or items"
    option :organization, type: :string, default: nil
    option :ph, type: :string, default: nil
    option :htdl, type: :string, default: nil
    option :sp, type: :string, default: nil
    def organization_holdings_overlap
      run_common_job(Reports::OverlapReport, options)
    end

    desc "holdings-by-date", "List the last time an org submitted holdings, grouped by org and mono_multi_serial"
    def holdings_by_date
      run_common_job(Reports::HoldingsByDateReport, options)
    end

    desc "shared-print-newly-ingested (--start_date=x) (--ht_item_ids_file=y)",
      "Get list of volumes ingested since DATE, for SP purposes"
    option :start_date, type: :string, default: nil
    option :ht_item_ids_file, type: :string, default: nil
    def shared_print_newly_ingested
      run_common_job(Reports::SharedPrintNewlyIngested, options)
    end

    desc "shared-print-phase-count (--phase=x)",
      "Get tally of commitments per organization in the given phase"
    option :phase, type: :numeric, default: nil
    def shared_print_phase_count
      run_common_job(Reports::SharedPrintPhaseCount, options)
    end

    desc "weeding-decision ORGANIZATION", "Generate a report to help ORG decide what to weed"
    def weeding_decision(organization)
      run_common_job(Reports::WeedingDecision, options, organization)
    end
  end

  class PHCTL < Thor
    # Run inline instead of with sidekiq
    class_option :inline, type: :boolean

    def self.exit_on_failure?
      true
    end

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

    desc "scrub ORG", "Download ORG's new files from DropBox and load them"
    # Only set force_holding_loader_cleanup_test to true in testing.
    option :force_holding_loader_cleanup_test, type: :boolean, default: false
    option :force, type: :boolean, default: false
    def scrub(org)
      Scrub::ScrubRunner.new(org, options).run
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

    desc "cleanup", "Cleanup operations"
    subcommand "cleanup", Cleanup
  end
end
