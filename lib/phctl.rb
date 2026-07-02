require "thor"

require "alma_holdings"
require "clusterable/holding"
require "sidekiq_jobs"
require "utils/file_transfer"
require "utils/holdings_preflight"
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
      "Parse Alma holdings xml files from ORG"
    option :organization, type: :string
    option :files, type: :array
    option :output_dir, type: :string, default: nil

    def parse_holdings_xml
      run_common_job(AlmaHoldingsXmlParser, options)
    end
  end

  class Report < JobCommand
    desc "costreport (--organization ORG) (--target_cost COST) (--frequency-table /path/to/table.json) (--working-directory /path/to/frequency/tables) (--ht-item-count NUM) (--ht-item-pd-count NUM)", "Run a cost report given existing frequency tables. One of --frequency-table or --working-directory must be provided."
    option :organization, type: :string, default: nil
    option :target_cost, type: :numeric, default: nil
    option :frequency_table, type: :string, default: nil, desc: "The full path to a .json frequency table to use for the report."
    option :working_directory, type: :string, default: nil, desc: "A directory containing .json frequency tables to sum for this cost report."
    option :ht_item_count, type: :numeric, default: nil
    option :ht_item_pd_count, type: :numeric, default: nil
    def costreport
      run_common_job(Reports::CostReport, options)
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

    desc "costreport [--ht-item-count NUM --ht-item-pd-count NUM] (--chunk-size SIZE)", "Dump records from solr, split into chunks of chunk-size records, generate frequency tables for each chunk, sum the resulting frequency tables, and generate a cost report based on that table."
    option :ht_item_count, type: :numeric
    option :ht_item_pd_count, type: :numeric
    def costreport_workflow
      ht_item_count = options[:ht_item_count]
      ht_item_pd_count = options[:ht_item_pd_count]

      if !ht_item_count || !ht_item_pd_count
        Services.logger.info("Getting item counts...")

        ht_item_count = Clusterable::HtItem.count
        Services.logger.info("Num volumes: #{ht_item_count}")
        ht_item_pd_count = Clusterable::HtItem.pd_count
        Services.logger.info("Num pd volumes: #{ht_item_pd_count}")
      end

      components = {
        data_source: component(Workflows::CostReport::DataSource),
        mapper: component(Workflows::CostReport::Analyzer),
        reducer: component(Reports::CostReport,
          {
            ht_item_count: ht_item_count,
            ht_item_pd_count: ht_item_pd_count
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

  class Holdings < JobCommand
    desc "count ORGANIZATION", "Show holdings in the database for ORGANIZATION, broken down by format"
    def count(org)
      result = Utils::HoldingsPreflight.new.format_counts(org)
      puts "#{org} holdings by format:"
      result[:counts].each { |r| puts "  #{r[:format]}:  #{r[:count]}" }
      puts "Total: #{result[:total]}"
    end

    desc "file-count REMOTE_PATH", "Count lines in a remote holdings file via rclone"
    def file_count(remote_path)
      puts Utils::FileTransfer.new.cat(remote_path, &:count)
    end

    desc "file-sample REMOTE_PATH", "Print first N lines of a remote holdings file"
    option :lines, type: :numeric, default: 50
    def file_sample(remote_path)
      Utils::FileTransfer.new.cat(remote_path) do |io|
        io.each_line.first(options[:lines]).each { |line| print line }
      end
    end

    desc "dir-counts REMOTE_DIR", "Count lines in each .tsv file in a remote directory"
    def dir_counts(remote_dir)
      result = Utils::HoldingsPreflight.new.dir_counts(remote_dir)
      result[:counts].each { |r| puts "#{r[:name]}: #{r[:count]}" }
      puts "Total: #{result[:total]}"
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
    option :type_check, type: :string, default: "check", desc: "check, delete, or append (see full description)."
    long_desc <<~DESC, wrap: false
      Download new files for ORG from DropBox and load them

      The --type-check option controls policy for new holdings that do not match previous loaded types.
      Possible values:
        check  - Refuse to load any type (mpm, spm, ser, mon, mix) that is not in the DB.
                 Does not generate an error if ORG has no previous holdings data.
        delete - Back up and delete types that are not represented in the new files.
        append - Add new holdings types without deleting any other types.
                 Typically this would be used to correct a failed load for one file,
                 in order to leave the other types intact.
    DESC
    def scrub(org)
      Scrub::ScrubRunner.new(org, options).run
    end

    desc "scrub_file ORG FILENAME", "Download and scrub a specific file for ORG from Dropbox without loading"
    def scrub_file(org, filename)
      Scrub::ScrubRunner.new(org, options).scrub_file(filename)
    rescue => err
      warn err.message
      exit 1
    end

    desc "convert-xml ORG", "Download ORG's Alma XML holdings, convert to TSV, and upload"
    def convert_xml(org)
      AlmaHoldings.new(organization: org).run
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

    desc "holdings SUBCOMMAND", "Pre-flight inspection of holdings"
    subcommand "holdings", Holdings
  end
end
