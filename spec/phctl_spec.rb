# frozen_string_literal: true

require "spec_helper"
require "phctl"

RSpec.describe "PHCTL::PHCTL", type: :sidekiq_fake do
  commands = {
    %w[load holdings somefile] => Jobs::Load::Holdings,
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
    %w[report phase3-oclc-registration instid] => Jobs::Common,
    %w[report shared-print-phase-count --phase 1] => Jobs::Common,
    # Has wrappers in holdings/jobs
    %w[report member-counts infile outpath] => Jobs::Common,
    %w[report costreport] => Jobs::Common,
    %w[report costreport --organization
      someinst --target-cost 123456] => Jobs::Common,
    %w[report frequency-table ht_item_file output_dir] => Jobs::Common,
    %w[report weeding_decision someinst] => Jobs::Common,
    %w[parse parse-holdings-xml] => Jobs::Common,
    %w[backup holdings --organization umich --mono_multi_serial mon] => Jobs::Backup::Holdings
    %w[workflow costreport] => Jobs::Common,
    %w[workflow overlap instid] => Jobs::Common

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

  describe "report costreport" do
    include_context "with tables for holdings"

    it "accepts a directory for frequency tables" do
      PHCTL::PHCTL.start(["report", "costreport", "--working-directory", "/freq/table/dir"])

      expect(Jobs::Common.jobs[0]["args"])
        .to eq(["Reports::CostReport",
          {"working_directory" => "/freq/table/dir"}])
    end

    it "accepts a file for frequency table" do
      PHCTL::PHCTL.start(["report", "costreport", "--frequency-table", "/path/to/freqtable.json"])

      expect(Jobs::Common.jobs[0]["args"])
        .to eq(["Reports::CostReport",
          {"frequency_table" => "/path/to/freqtable.json"}])
    end
  end

  xdescribe "running inline" do
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
