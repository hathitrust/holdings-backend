require "thor"
require "sidekiq_jobs"
require "workflow_component"

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
    desc "ht-items FILENAME", "Add HT Items"
    def ht_items(filename)
      run_job(Jobs::Load::HtItems, filename)
    end

    # This could be broken into "load concordance delta" and "load concordance file"
    # if FILENAME_OR_DATE is too confusing.
    desc "concordance FILENAME_OR_DATE", "Load concordance deltas if argument is YYYYMMDD, or a full concordance file"
    def concordance(filename_or_date)
      run_job(Jobs::Load::Concordance, filename_or_date)
    end

    desc "holdings FILENAME", "Loads scrubbed holdings."
    def holdings(filename)
      run_job(Jobs::Load::Holdings, filename)
    end
  end

  class Concordance < JobCommand
    desc "validate INFILE OUTFILE", "Validate a concordance file"
    def validate(infile, outfile)
      run_job(Jobs::Concordance::Validate, infile, outfile)
    end

    desc "delta OLD_FILE NEW_FILE", "Compute deltas between two concordance files"
    def delta(old, new)
      run_job(Jobs::Concordance::Delta, old, new)
    end
  end

  class Backup < JobCommand
    desc "holdings --organization ORG --mono_multi_serial LIST", "Back up holdings for organization"
    option :organization, type: :string
    option :mono_multi_serial, type: :array, default: []

    def holdings
      options["mono_multi_serial"].each do |mono_multi_serial|
        run_job(Jobs::Backup::Holdings, options["organization"], mono_multi_serial)
      end
    end
  end

  class Parse < JobCommand
    desc "parse-holdings-xml --organization ORG --files LIST (--output-dir PATH)",
      "Parse ExLibris holdings xml files from ORG"
    option :organization, type: :string
    option :files, type: :array
    option :output_dir, type: :string, default: nil

    def parse_holdings_xml
      run_common_job(ExLibrisHoldingsXmlParser, options)
    end
  end

  class Report < JobCommand
    desc "costreport (--organization ORG) (--target_cost COST) (--frequency-table /path/to/table.json) (--working-directory /path/to/frequency/tables)", "Run a cost report given existing frequency tables. One of --frequency-table or --working-directory must be provided."
    option :organization, type: :string, default: nil
    option :target_cost, type: :numeric, default: nil
    option :frequency_table, type: :string, default: nil, desc: "The full path to a .json frequency table to use for the report."
    option :working_directory, type: :string, default: nil, desc: "A directory containing .json frequency tables to sum for this cost report."
    def costreport
      run_common_job(Reports::CostReport, options)
    end

    desc "member-counts COST_RPT_FREQ_FILE OUTPUT_DIR", "Calculate member counts"
    def member_counts(cost_rpt_freq_file, output_dir)
      run_common_job(Reports::MemberCounts, options, cost_rpt_freq_file, output_dir)
    end

    desc "holdings-by-date", "List the last time an org submitted holdings, grouped by org and mono_multi_serial"
    def holdings_by_date
      run_common_job(Reports::HoldingsByDateReport, options)
    end
  end

  class Workflow < JobCommand
    class_option :records_per_job, type: :numeric, default: Settings.mapreduce.records_per_job
    class_option :test_mode, type: :boolean, default: false
    class_option :cleanup, type: :boolean, default: true, desc: "remove intermediate files in work directory on completion"

    no_commands do
      def component(...)
        WorkflowComponent.new(...)
      end

      def run_workflow(components)
        params = base_params.merge(components: components)
        if parent_options[:inline]
          Jobs::MapReduceWorkflow.perform_now(**params)
        else
          Jobs::MapReduceWorkflow.perform_async(**params)
        end
      end

      def base_params
        {
          records_per_job: options[:records_per_job],
          cleanup: options[:cleanup],
          test_mode: options[:test_mode]
        }
      end
    end

    desc "costreport --ht-item-count NUM --ht-item-pd-count NUM (--chunk-size SIZE)", "Dump records from solr, split into chunks of chunk-size records, generate frequency tables for each chunk, sum the resulting frequency tables, and generate a cost report based on that table."
    option :ht_item_count, type: :numeric
    option :ht_item_pd_count, type: :numeric
    def costreport_workflow
      components = {
        data_source: component(Workflows::CostReport::DataSource),
        mapper: component(Workflows::CostReport::Analyzer),
        reducer: component(Reports::CostReport,
          {
            ht_item_count: options[:ht_item_count],
            ht_item_pd_count: options[:ht_item_pd_count]
          })
      }

      run_workflow(components)
    end

    desc "overlap ORGANIZATION [--matching-members-count]", "Generate an overlap report for the given organization"
    option :matching_members_count, type: :boolean, desc: "Include count of HT members that report holdings for each item"
    def overlap_workflow(org)
      params = {organization: org}
      if options[:matching_members_count]
        params[:report_record_class] = Overlap::ReportRecord::MatchingMembersCount
      end

      components = {
        data_source: component(Workflows::OverlapReport::DataSource, params),
        mapper: component(Workflows::OverlapReport::Analyzer, params),
        reducer: component(Workflows::OverlapReport::Writer, params)
      }

      run_workflow(components)
    end

    desc "estimate OCN_FILE", "Run an estimate"
    def estimate(ocn_file)
      components = {
        data_source: component(Workflows::Estimate::DataSource, {ocn_file: ocn_file}),
        mapper: component(Workflows::Estimate::Analyzer),
        reducer: component(Workflows::Estimate::Writer, {ocn_file: ocn_file})
      }

      run_workflow(components)
    end

    desc "deposit_holdings_analysis", "Analyze holdings from contributors of deposited items"
    def deposit_holdings_analysis
      components = {
        data_source: component(Workflows::DepositHoldingsAnalysis::DataSource),
        mapper: component(Workflows::DepositHoldingsAnalysis::Analyzer),
        reducer: component(Workflows::DepositHoldingsAnalysis::Writer)
      }

      run_workflow(components)
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
    option :force_holding_loader_cleanup_test, type: :boolean, default: false, desc: "For testing only"
    option :force, type: :boolean, default: false, desc: "Load holdings despite > 5% difference in count from previous holdings"
    option :type_check, type: :boolean, default: true, desc: "Check whether holdings match previous loaded types."
    def scrub(org)
      Scrub::ScrubRunner.new(org, options).run
    end

    # report
    desc "report", "Generate a report"
    subcommand "report", Report

    desc "load <clusterable> <args>", "Load clusterable records"
    subcommand "load", Load

    desc "parse", "various parsing commands"
    subcommand "parse", Parse

    desc "backup", "various backup commands"
    subcommand "backup", Backup

    desc "concordance", "Validate or validate and compute deltas"
    subcommand "concordance", Concordance

    desc "workflow", "Parallelized workflows for generating reports"
    subcommand "workflow", Workflow
  end
end
