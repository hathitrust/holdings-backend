require "services"
require "sidekiq"
require "cost_report_workflow"
require "concordance_processing"
require "ex_libris_holdings_xml_parser"
require "loader/file_loader"
require "loader/holding_loader"
require "loader/shared_print_loader"
require "reports/commitment_replacements"
require "reports/cost_report"
require "reports/dynamic"
require "reports/estimate"
require "reports/etas_organization_overlap_report"
require "reports/frequency_table_from_solr"
require "reports/holdings_by_date_report"
require "reports/member_counts"
require "reports/oclc_registration"
require "reports/overlap_report"
require "reports/phase3_oclc_registration"
require "reports/rare_uncommitted"
require "reports/shared_print_newly_ingested"
require "reports/shared_print_phase_count"
require "reports/uncommitted_holdings"
require "reports/weeding_decision"
require "scrub/scrub_runner"
require "shared_print/deprecator"
require "shared_print/phase_3_validator"
require "shared_print/replacer"
require "shared_print/updater"

require_relative "../config/initializers/sidekiq"

if $0 == "sidekiq"
  Services.register(:logger) { Sidekiq.logger }
end

module Jobs
  class Common
    include Sidekiq::Job
    def perform(klass, options = {}, *)
      Object.const_get(klass).new(*, **options.transform_keys { |k| k.to_sym }).run
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

  module SharedPrintOps
    class Deprecate
      include Sidekiq::Job
      def perform(verbose, infiles)
        SharedPrint::Deprecator.new(verbose: verbose).run(infiles)
      end
    end
  end
end
