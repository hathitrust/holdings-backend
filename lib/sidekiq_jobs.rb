require "services"
require "sidekiq"
require "concordance_processing"
require "ex_libris_holdings_xml_parser"
require "loader/concordance_loader"
require "loader/file_loader"
require "loader/holding_loader"
require "loader/shared_print_loader"
require "reports/commitment_replacements"
require "reports/cost_report"
require "reports/dynamic"
require "reports/holdings_by_date_report"
require "reports/member_counts"
require "reports/oclc_registration"
require "reports/phase3_oclc_registration"
require "reports/rare_uncommitted"
require "reports/shared_print_newly_ingested"
require "reports/shared_print_phase_count"
require "reports/uncommitted_holdings"
require "reports/weeding_decision"
require "scrub/pre_load_backup"
require "scrub/scrub_runner"
require "shared_print/deprecator"
require "shared_print/phase_3_validator"
require "shared_print/replacer"
require "shared_print/updater"
require "workflow_component"
require "workflows/cost_report"
require "workflows/estimate"
require "workflows/map_reduce"
require "workflows/overlap_report"

require_relative "../config/initializers/sidekiq"

if $0 == "sidekiq"
  Services.register(:logger) { Sidekiq.logger }
end

module Jobs
  # make functions available as Jobs::whatever

  module_function

  # prepare parameters such that they can get passed through JSON
  def prepare_params(params)
    params
      .transform_keys { |k| k.to_s }
      .transform_values { |v| prepare_value(v) }
  end

  def prepare_value(value)
    case value
    when Hash
      prepare_params(value)
    when Array
      value.map { |entry| prepare_value(entry) }
    when Symbol, Class
      value.to_s
    when String, Integer, true, false, nil
      value
    when ->(v) { v.respond_to?(:to_h) }
      prepare_params(value.to_h)
    else
      raise "Can't prepare value '#{value}' as sidekiq job param"
    end
  end

  def symbolize_keys(params)
    params.transform_keys { |k| k.to_sym }
  end

  # Symbolizes all keys in the hash and recursively symbolize keys in any values
  # that are hashes
  def symbolize(hash)
    symbolize_keys(hash).transform_values do |value|
      case value
      when Hash
        symbolize(value)
      else
        value
      end
    end
  end

  class Common
    include Sidekiq::Job
    def perform(klass, options = {}, *)
      Object.const_get(klass).new(*, **Jobs.symbolize_keys(options)).run
    end

    def self.perform_async(klass, options = {}, *)
      super(klass.to_s, Jobs.prepare_params(options), *)
    end
  end

  class MapReduceWorkflow
    include Sidekiq::Job

    def perform(options)
      params = Jobs.symbolize(options)
      params[:components].transform_values! do |component|
        WorkflowComponent.new(
          Object.const_get(component[:component_class]),
          component.fetch(:params, {})
        )
      end
      Workflows::MapReduce.new(**params).run
    end

    def self.perform_now(**params)
      Workflows::MapReduce.new(**params).run
    end

    def self.perform_async(**params)
      super(Jobs.prepare_params(params))
    end
  end

  module Load
    class Commitments
      include Sidekiq::Job
      def perform(filename)
        Services.logger.info "Loading Shared Print Commitments: #{filename}"
        Loader::FileLoader.new(batch_loader: Loader::SharedPrintLoader.for(filename))
          .load(filename, filehandle: Loader::SharedPrintLoader.filehandle_for(filename))
      end
    end

    class Concordance
      include Sidekiq::Job
      def perform(filename_or_date)
        batch_loader = Loader::ConcordanceLoader.for(filename_or_date)
        Services.logger.info "Loading with #{batch_loader.class} for #{filename_or_date}"
        # Allow batch loader subclass to truncate DB if loading full concordance
        batch_loader.prepare
        Loader::FileLoader.new(batch_loader: batch_loader)
          .load(batch_loader.adds_file)
        if batch_loader.deletes?
          Loader::FileLoader.new(batch_loader: batch_loader)
            .batch_load_deletes(batch_loader.deletes_file)
        end
        Services.logger.info "Finished Concordance load for #{filename_or_date}."
      end
    end

    class Holdings
      include Sidekiq::Job
      def perform(filename)
        Services.logger.info "Adding Print Holdings from #{filename}."
        Loader::FileLoader.new(batch_loader: Loader::HoldingLoader.for(filename))
          .load(filename, skip_header_match: /\A\s*OCN/)
        Services.logger.info "Finished Adding Print Holdings from #{filename}."
      end
    end
  end

  module Concordance
    class Validate
      include Sidekiq::Job
      def perform(infile, outfile)
        ConcordanceProcessing.new.validate(infile, outfile)
      end
    end

    class Delta
      include Sidekiq::Job
      def perform(old, new)
        ConcordanceProcessing.new.delta(old, new)
      end
    end
  end

  module Backup
    class Holdings
      include Sidekiq::Job
      def perform(organization, mono_multi_serial)
        Services.logger.info "Starting backup job for #{organization}:#{mono_multi_serial}"
        backup_obj = Scrub::PreLoadBackup.new(
          organization: organization,
          mono_multi_serial: mono_multi_serial
        )
        backup_obj.write_backup_file
        Services.logger.info "Wrote backup file for #{organization}:#{mono_multi_serial} to #{backup_obj.backup_path}"
      end
    end
  end

  module SharedPrintOps
    class Deprecate
      include Sidekiq::Job
      def perform(verbose, infiles)
        SharedPrint::Deprecator.new(verbose: verbose).run(infiles)
      end
    end
  end
end
