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
    %w[workflow overlap instid] => Jobs::MapReduceWorkflow,
    %w[workflow deposit_holdings_analysis] => Jobs::MapReduceWorkflow,
    %w[workflow non_current_holdings_analysis] => Jobs::MapReduceWorkflow

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

  describe "holdings" do
    let(:ft) { instance_double(Utils::FileTransfer) }

    before { allow(Utils::FileTransfer).to receive(:new).and_return(ft) }

    describe "count" do
      it "prints the format breakdown and total for an organization" do
        rows = [
          {mono_multi_serial: "spm", count: 1000},
          {mono_multi_serial: "ser", count: 500}
        ]
        allow(Clusterable::Holding).to receive(:format_counts).with("umich").and_return(rows)
        expect { PHCTL::PHCTL.start(["holdings", "count", "umich"]) }
          .to output("umich holdings by format:\n  spm:  1000\n  ser:  500\nTotal: 1500\n").to_stdout
      end
    end

    describe "file-count" do
      it "prints the line count of a remote file" do
        allow(ft).to receive(:cat)
          .with("dropbox:some/file.tsv")
          .and_yield(StringIO.new("line1\nline2\nline3\n"))
        expect { PHCTL::PHCTL.start(["holdings", "file-count", "dropbox:some/file.tsv"]) }
          .to output("3\n").to_stdout
      end
    end

    describe "dir-counts" do
      it "counts lines in each tsv file, skipping non-tsv files" do
        files = [
          {"Name" => "umich_mon_2025.tsv", "Path" => "umich_mon_2025.tsv", "IsDir" => false},
          {"Name" => "umich_ser_2025.tsv", "Path" => "umich_ser_2025.tsv", "IsDir" => false},
          {"Name" => "umich_mon_2025.log", "Path" => "umich_mon_2025.log", "IsDir" => false}
        ]
        allow(ft).to receive(:lsjson).with("dropbox:some/dir").and_return(files)
        allow(ft).to receive(:cat).with("dropbox:some/dir/umich_mon_2025.tsv").and_yield(StringIO.new("a\nb\nc\n"))
        allow(ft).to receive(:cat).with("dropbox:some/dir/umich_ser_2025.tsv").and_yield(StringIO.new("x\ny\n"))
        expect { PHCTL::PHCTL.start(["holdings", "dir-counts", "dropbox:some/dir"]) }
          .to output("umich_mon_2025.tsv: 3\numich_ser_2025.tsv: 2\nTotal: 5\n").to_stdout
      end

      it "skips subdirectory entries" do
        files = [
          {"Name" => "umich_mon_2025.tsv", "Path" => "umich_mon_2025.tsv", "IsDir" => false},
          {"Name" => "archive", "Path" => "archive", "IsDir" => true}
        ]
        allow(ft).to receive(:lsjson).with("dropbox:some/dir").and_return(files)
        allow(ft).to receive(:cat).with("dropbox:some/dir/umich_mon_2025.tsv").and_yield(StringIO.new("a\nb\n"))
        expect { PHCTL::PHCTL.start(["holdings", "dir-counts", "dropbox:some/dir"]) }
          .to output("umich_mon_2025.tsv: 2\nTotal: 2\n").to_stdout
      end

      it "prints only a total when no tsv files are present" do
        files = [
          {"Name" => "umich_mon_2025.log", "Path" => "umich_mon_2025.log", "IsDir" => false}
        ]
        allow(ft).to receive(:lsjson).with("dropbox:some/dir").and_return(files)
        expect { PHCTL::PHCTL.start(["holdings", "dir-counts", "dropbox:some/dir"]) }
          .to output("Total: 0\n").to_stdout
      end
    end

    describe "file-sample" do
      it "prints the first N lines of a remote file" do
        content = (1..100).map { |i| "line#{i}\n" }.join
        allow(ft).to receive(:cat)
          .with("dropbox:some/file.tsv")
          .and_yield(StringIO.new(content))
        expect { PHCTL::PHCTL.start(["holdings", "file-sample", "dropbox:some/file.tsv", "--lines", "3"]) }
          .to output("line1\nline2\nline3\n").to_stdout
      end
    end
  end

  describe "holdings rclone commands (integration)" do
    let(:test_dir) { "#{ENV["TEST_TMP"]}/holdings_rclone_test" }

    before do
      FileUtils.touch Settings.rclone_config_path
      FileUtils.rm_rf(test_dir)
      FileUtils.mkdir_p(test_dir)
    end

    describe "file-count" do
      it "counts lines in a local file" do
        File.write("#{test_dir}/umich_mon_2025.tsv", "line1\nline2\nline3\n")
        expect { PHCTL::PHCTL.start(["holdings", "file-count", "#{test_dir}/umich_mon_2025.tsv"]) }
          .to output("3\n").to_stdout
      end
    end

    describe "file-sample" do
      it "prints the first N lines" do
        File.write("#{test_dir}/umich_mon_2025.tsv", (1..100).map { |i| "line#{i}\n" }.join)
        expect { PHCTL::PHCTL.start(["holdings", "file-sample", "#{test_dir}/umich_mon_2025.tsv", "--lines", "3"]) }
          .to output("line1\nline2\nline3\n").to_stdout
      end

      it "prints all lines when file is shorter than --lines" do
        File.write("#{test_dir}/umich_mon_2025.tsv", "only\ntwo\n")
        expect { PHCTL::PHCTL.start(["holdings", "file-sample", "#{test_dir}/umich_mon_2025.tsv", "--lines", "50"]) }
          .to output("only\ntwo\n").to_stdout
      end
    end

    describe "dir-counts" do
      it "counts lines in each tsv file, skipping non-tsv files" do
        File.write("#{test_dir}/umich_mon_2025.tsv", "a\nb\nc\n")
        File.write("#{test_dir}/umich_ser_2025.tsv", "x\ny\n")
        File.write("#{test_dir}/umich_mon_2025.log", "ignored\n")
        expect { PHCTL::PHCTL.start(["holdings", "dir-counts", test_dir]) }
          .to output("umich_mon_2025.tsv: 3\numich_ser_2025.tsv: 2\nTotal: 5\n").to_stdout
      end

      it "skips subdirectory entries" do
        File.write("#{test_dir}/umich_mon_2025.tsv", "a\nb\n")
        FileUtils.mkdir_p("#{test_dir}/archive")
        expect { PHCTL::PHCTL.start(["holdings", "dir-counts", test_dir]) }
          .to output("umich_mon_2025.tsv: 2\nTotal: 2\n").to_stdout
      end

      it "prints only a total when no tsv files are present" do
        File.write("#{test_dir}/umich_mon_2025.log", "ignored\n")
        expect { PHCTL::PHCTL.start(["holdings", "dir-counts", test_dir]) }
          .to output("Total: 0\n").to_stdout
      end

      it "does not count tsv files in nested directories" do
        File.write("#{test_dir}/umich_mon_2025.tsv", "a\nb\n")
        FileUtils.mkdir_p("#{test_dir}/subdir")
        File.write("#{test_dir}/subdir/umich_ser_2025.tsv", "x\ny\nz\n")
        expect { PHCTL::PHCTL.start(["holdings", "dir-counts", test_dir]) }
          .to output("umich_mon_2025.tsv: 2\nTotal: 2\n").to_stdout
      end

      it "outputs files sorted alphabetically" do
        File.write("#{test_dir}/umich_zzz.tsv", "z\n")
        File.write("#{test_dir}/umich_aaa.tsv", "a\nb\n")
        expect { PHCTL::PHCTL.start(["holdings", "dir-counts", test_dir]) }
          .to output("umich_aaa.tsv: 2\numich_zzz.tsv: 1\nTotal: 3\n").to_stdout
      end
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
