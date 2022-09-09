# frozen_string_literal: true

require "spec_helper"
require "phctl"

RSpec.describe "PHCTL::PHCTL", type: :sidekiq_fake do
  def phctl(*args)
    PHCTL::PHCTL.start(*args)
  end

  commands = {
    %w[load commitments somefile] => Jobs::Load::Commitments,
    %w[load concordance date] => Jobs::Load::Concordance,
    %w[load ht-items somefile] => Jobs::Load::HtItems,
    %w[load cluster-file somefile] => Jobs::Load::ClusterFile,
    %w[load holdings somefile] => Jobs::Load::Holdings,
    %w[cleanup holdings instid date] => Jobs::Cleanup::Holdings,
    %w[concordance validate infile outfile] => Jobs::Concordance::Validate,
    %w[concordance delta oldfile newfile] => Jobs::Concordance::Delta,
    %w[sp update infile] => Jobs::Common,
    %w[sp replace infile] => Jobs::Common,
    %w[sp deprecate infile] => Jobs::SharedPrintOps::Deprecate,
    %w[sp deprecate infile --verbose] => Jobs::SharedPrintOps::Deprecate,
    %w[report estimate ocnfile] => Jobs::Common,
    %w[report eligible-commitments ocnfile] => Jobs::Common,
    %w[report uncommitted-holdings] => Jobs::Common,

    # Has wrappers in holdings/jobs
    %w[report member-counts infile outpath] => Jobs::Common,
    %w[report costreport] => Jobs::Common,
    %w[report costreport --organization
      someinst --target-cost 123456] => Jobs::Common,
    %w[report etas-overlap] => Jobs::Common,
    %w[report etas-overlap someinst] => Jobs::Common,
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