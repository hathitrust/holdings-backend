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
require "concordance_processing"
require "ocn_concordance_diffs"
require "reports/compile_cost_reports"
require "reports/compile_estimated_IC_costs"
require "reports/compile_member_counts_report"
require "shared_print/updater"
require "shared_print/replacer"
require "shared_print/deprecator"

# Don't want to do this by default when we aren't running under sidekiq
Services.register(:logger) { Sidekiq.logger }

module Jobs
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
    class Update
      include Sidekiq::Job
      def perform(infile)
        SharedPrint::Updater.new(infile).run
      end
    end

    class Replace
      include Sidekiq::Job
      def perform(infile)
        SharedPrint::Replacer.new(infile).run
      end
    end

    class Deprecate
      include Sidekiq::Job
      def perform(verbose, infiles)
        SharedPrint::Deprecator.new(verbose: verbose).run(infiles)
      end
    end
  end

  module Report
    class CostReport
      include Sidekiq::Job
      def perform(organization, target_cost)
        CompileCostReport.new.run(organization, target_cost)
      end
    end

    class Estimate
      include Sidekiq::Job
      def perform(ocn_file)
        CompileEstimate.new.run(ocn_file)
      end
    end

    class MemberCounts
      include Sidekiq::Job
      def perform(cost_rpt_freq_file, output_dir)
        CompileMemberCounts.new.run(cost_rpt_freq_file, output_dir)
      end
    end

    class EtasOverlap
      include Sidekiq::Job
      def perform(org)
        rpt = Reports::EtasOrganizationOverlapReport.new(org)
        rpt.run
        rpt.move_reports
      end
    end

    class EligibleCommitments
      include Sidekiq::Job
      def perform(ocns)
        Reports::CommitmentReplacements.new.run(ocns)
      end
    end

    class UncommittedHoldings
      include Sidekiq::Job
      def perform(**kwargs)
        Reports::UncommittedHoldings.new(**kwargs).run
      end
    end

    class RareUncommittedCounts
      include Sidekiq::Job
      def perform(**kwargs)
        Reports::RareUncommitted.new(**kwargs).run
      end
    end
  end
end
