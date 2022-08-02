# frozen_string_literal: true

require "spec_helper"
require "phctl"

RSpec.describe "PHCTL::PHCTL" do
  def phctl(*args)
    PHCTL::PHCTL.start(*args)
  end

  before(:each) do
    Sidekiq::Worker.clear_all
  end

  commands = {
    %w[load commitments somefile] => Jobs::Load::Commitments,
    %w[load ht_items somefile] => Jobs::Load::HtItems,
    %w[load cluster_file somefile] => Jobs::Load::ClusterFile,
    %w[concordance validate infile outfile] => Jobs::Concordance::Validate,
    %w[concordance delta oldfile newfile] => Jobs::Concordance::Delta,
    %w[sp update infile] => Jobs::SharedPrintOps::Update,
    %w[sp replace infile] => Jobs::SharedPrintOps::Replace,
    %w[sp deprecate infile] => Jobs::SharedPrintOps::Deprecate,
    %w[sp deprecate infile --verbose] => Jobs::SharedPrintOps::Deprecate,
    %w[report estimate ocnfile] => Jobs::Report::Estimate,
    %w[report eligible-commitments ocnfile] => Jobs::Report::EligibleCommitments,
    %w[report uncommitted-holdings] => Jobs::Report::UncommittedHoldings,

    # Has wrappers in holdings/jobs
    %w[report member-counts infile outpath] => Jobs::Report::MemberCounts,
    %w[report costreport] => Jobs::Report::CostReport,
    %w[report costreport --organization
      someinst --target-cost 123456] => Jobs::Report::CostReport,
    %w[report etas-overlap] => Jobs::Report::EtasOverlap,
    %w[report etas-overlap someinst] => Jobs::Report::EtasOverlap,
    %w[load concordance somefile] => Jobs::Load::Concordance

    # Not covered by phctl
    # bin/cost_changes.sh
    # bin/prep_loadfiles.sh
    # jobs/update_overlap_table.rb
  }

  commands.each do |args, job_class|
    it "command '#{args.join(" ")}' queues a #{job_class}" do
      expect { PHCTL::PHCTL.start(args) }.to change(job_class.jobs, :size).by(1)
    end
  end
end
