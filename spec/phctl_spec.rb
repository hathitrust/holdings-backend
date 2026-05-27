# frozen_string_literal: true

require "spec_helper"
require "phctl"

RSpec.describe "PHCTL::PHCTL", type: :sidekiq_fake do
  commands = {
    %w[load holdings somefile] => Jobs::Load::Holdings,
    %w[concordance validate infile outfile] => Jobs::Concordance::Validate,
    %w[concordance delta oldfile newfile] => Jobs::Concordance::Delta,
    # Has wrappers in holdings/jobs
    %w[report costreport] => Jobs::Common,
    %w[report costreport --organization
      someinst --target-cost 123456] => Jobs::Common,
    %w[parse parse-holdings-xml] => Jobs::Common,
    %w[backup holdings --organization umich --mono_multi_serial mon] => Jobs::Backup::Holdings,
    %w[workflow costreport] => Jobs::MapReduceWorkflow,
    %w[workflow estimate somefile] => Jobs::MapReduceWorkflow,
    %w[workflow overlap instid] => Jobs::MapReduceWorkflow

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

    it "accepts item and pd counts" do
      PHCTL::PHCTL.start(["report", "costreport", "--ht_item_count", "2", "--ht_item_pd_count", "1"])

      expect(Jobs::Common.jobs[0]["args"])
        .to eq(["Reports::CostReport",
          {"ht_item_count" => 2, "ht_item_pd_count" => 1}])
    end
  end

  describe "running inline" do
    include_context "with tables for holdings"

    context "load holdings" do
      let(:args) { ["load", "holdings", "--inline", fixture("umich_spm_2025-10-20-testdata.ndj")] }
      it "does not queue a sidekiq job" do
        expect { PHCTL::PHCTL.start(args) }
          .not_to change(Jobs::Load::Holdings.jobs, :size)
      end

      it "loads holdings from the given file" do
        expect { PHCTL::PHCTL.start(args) }
          .to change { Clusterable::Holding.count }.by(5)
      end
    end

    context "common job" do
      let(:args) { ["report", "costreport", "--inline", "--frequency-table", fixture("freqtable.json")] }
      it "does not queue a sidekiq job" do
        expect { PHCTL::PHCTL.start(args) }
          .not_to change(Jobs::Common.jobs, :size)
      end

      it "generates a cost report" do
        PHCTL::PHCTL.start(args)
        year = Time.new.year.to_s
        expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/cost_reports/#{year}/*").first))
          .to match(/Target cost: 9999/)
      end
    end
  end
end
