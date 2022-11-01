require "services"
require "sidekiq"
require "loader/file_loader"
require "loader/cluster_loader"
require "loader/ht_item_loader"
require "loader/holding_loader"
require "loader/shared_print_loader"
require "reports/commitment_replacements"
require "reports/etas_organization_overlap_report"
require "reports/uncommitted_holdings"
require "reports/rare_uncommitted"
require "reports/cost_report"
require "reports/estimate"
require "reports/member_counts"
require "reports/oclc_registration"
require "concordance_processing"
require "ocn_concordance_diffs"
require "scrub/scrub_runner"
require "shared_print/updater"
require "shared_print/replacer"
require "shared_print/deprecator"
require "utils/null_progress_tracker"

require_relative "../config/initializers/sidekiq"

if $0 == 'sidekiq'
  Services.register(:logger) { Sidekiq.logger }
end

module Jobs
  class Common
    include Sidekiq::Job
    def perform(klass, options = {}, *args)
      Object.const_get(klass).new(*args, **options.symbolize_keys).run
    end
  end

  module Load
    class Commitments
      include Sidekiq::Job
      def perform(filename)
        Services.logger.info "Loading Shared Print Commitments: #{filename}"
        Loader::FileLoader.new(batch_loader: Loader::SharedPrintLoader.new).load(filename)
      end
    end

    class HtItems
      include Sidekiq::Job
      def perform(filename)
        Services.logger.info "Updating HT Items."
        Loader::FileLoader.new(batch_loader: Loader::HtItemLoader.new).load(filename)
      end
    end

    class Concordance
      include Sidekiq::Job
      def perform(date)
        OCNConcordanceDiffs.new(Date.parse(date)).load
      end
    end

    class ClusterFile
      include Sidekiq::Job
      def perform(filename)
        loader = Loader::ClusterLoader.new
        loader.load(filename)
        Services.logger.info loader.stats
      end
    end

    class Holdings
      include Sidekiq::Job
      def perform(filename)
        Services.logger.info "Adding Print Holdings from #{filename}."
        Loader::FileLoader.new(batch_loader: Loader::HoldingLoader.for(filename))
          .load(filename, skip_header_match: /\A\s*OCN/)
      end
    end
  end

  module Cleanup
    class Holdings
      include Sidekiq::Job
      def perform(instid, date)
        Clustering::ClusterHolding.delete_old_holdings(instid, Date.parse(date))
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
