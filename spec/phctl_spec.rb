# frozen_string_literal: true

require "spec_helper"
require "phctl"

RSpec.describe "PHCTL::PHCTL", type: :sidekiq_fake do
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
    %w[sp phase3load somefile] => Jobs::Common,
    %w[report estimate ocnfile] => Jobs::Common,
    %w[report eligible-commitments ocnfile] => Jobs::Common,
    %w[report uncommitted-holdings] => Jobs::Common,
    %w[report oclc-registration instid] => Jobs::Common,

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

  describe "running inline" do
    before(:each) do
      Cluster.each(&:delete)
    end

    context "load ht_items" do
      it "does not queue a sidekiq job" do
        expect { PHCTL::PHCTL.start(["load", "ht_items", "--inline", fixture("hathifile_sample.txt")]) }
          .not_to change(Jobs::Load::HtItems.jobs, :size)
      end

      it "does the thing" do
        expect { PHCTL::PHCTL.start(["load", "ht_items", "--inline", fixture("hathifile_sample.txt")]) }
          .to change { cluster_count(:ht_items) }.by(5)
      end
    end

    context "common job" do
      # need some data or it gets upset
      before(:each) do
        PHCTL::PHCTL.start(["load", "cluster_file", "--inline", fixture("cluster_2503661.json")])
      end

      it "does not queue a sidekiq job" do
        expect { PHCTL::PHCTL.start(["report", "costreport", "--inline"]) }
          .not_to change(Jobs::Common.jobs, :size)
      end

      it "does the thing" do
        PHCTL::PHCTL.start(["report", "costreport", "--inline"])
        year = Time.new.year.to_s
        expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/cost_reports/#{year}/*").first))
          .to match(/Target cost: 9999/)
      end
    end
  end
end
