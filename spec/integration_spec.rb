# frozen_string_literal: true

require "spec_helper"
require "phctl"

RSpec.describe "phctl integration" do
  def phctl(*args)
    PHCTL::PHCTL.start(args)
  end

  include_context "with tables for holdings"

  describe "load" do
    xdescribe "commitments" do
      it "loads json file" do
        expect { phctl("load", "commitments", fixture("sp_commitment.ndj")) }
          .to change { cluster_count(:commitments) }.by(1)
      end

      it "loads tsv file with policies" do
        expect { phctl("load", "commitments", fixture("sp_commitment_policies.tsv")) }
          .to change { cluster_count(:commitments) }.by(3)
      end

      it "loads tsv file with phase 3 commitments" do
        # Setup, need populated clusters to load commitments
        [2, 3].each do |ocn|
          cluster_tap_save(
            build(:ht_item, ocns: [ocn]),
            build(:holding, ocn: ocn, organization: "umich")
          )
        end
        expect { phctl("sp", "phase3load", fixture("phase_3_commitments.tsv")) }
          .to change { cluster_count(:commitments) }.by(2)
      end
    end

    it "Holdings loads holdings" do
      expect { phctl("load", "holdings", fixture("umich_fake_testdata.ndj")) }
        .to change { Clusterable::Holding.table.count }.by(10)
    end

    describe "concordance" do
      around(:each) do |example|
        saved_concordance_path = Settings.concordance_path
        Settings.concordance_path = File.join(__dir__, "fixtures", "concordance")
        example.run
        Settings.concordance_path = saved_concordance_path
      end

      # Adds 5 and deletes 1
      it "loads adds and deletes" do
        expect { phctl("load", "concordance", "20220801") }
          .to change { Services[:concordance_table].count }.by(4)
      end

      # Removes everything and adds 7
      it "loads full concordance" do
        concordance_file = File.join(Settings.concordance_path, "raw", "not_cycle_graph.tsv")
        phctl("load", "concordance", concordance_file)
        expect(Services[:concordance_table].count).to eq(7)
      end
    end
  end

  describe "Concordance" do
    it "Validate produces output and log" do
      def cleanup(output)
        File.unlink(output) if File.exist?(output)
        File.unlink("#{output}.log") if File.exist?("#{output}.log")
      end

      input = fixture("concordance_sample.txt")
      output = "#{ENV["TEST_TMP"]}/concordance_output"
      cleanup(output)

      begin
        phctl("concordance", "validate", input, output)
        expect(File.size(output)).to be > 0
        expect(File).to exist("#{output}.log")
      ensure
        cleanup(output)
      end
    end

    it "Delta produces adds and deletes" do
      validated_path = "#{ENV["TEST_TMP"]}/concordance/validated"
      diffs_path = "#{ENV["TEST_TMP"]}/concordance/diffs"

      FileUtils.mkdir_p(validated_path)
      FileUtils.mkdir_p(diffs_path)
      FileUtils.cp(fixture("concordance_sample.txt"), validated_path)
      FileUtils.cp(fixture("concordance_sample_2.txt"), validated_path)
      Jobs::Concordance::Delta.new.perform(
        File.join(validated_path, "concordance_sample.txt"),
        File.join(validated_path, "concordance_sample_2.txt")
      )
      expect(File.size("#{diffs_path}/comm_diff_#{Date.today}.txt.adds")).to be > 0
      expect(File.size("#{diffs_path}/comm_diff_#{Date.today}.txt.deletes")).to be > 0
    end
  end

  # SharedPrintOps - integration tests are in the respective SharedPrint class

  describe "Report" do
    include_context "with mocked solr response"
    include_context "with complete data for one cluster"

    it "CostReportWorkflow produces output" do
      # item counts match what we have in the mock solr response
      phctl(*%w[report costreport-workflow --ht-item-count 16 --ht-item-pd-count 5 --inline-callback-test])
      year = Time.new.year.to_s

      costreport = File.read(Dir.glob("#{ENV["TEST_TMP"]}/cost_reports/#{year}/*").first)
      expect(costreport).to match(/Num volumes: 16/)
      expect(costreport).to match(/Num pd volumes: 5/)
    end

    it "Estimate produces output" do
      phctl("report", "estimate", fixture("ocn_list.txt"))

      expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/estimates/ocn_list-estimate-*.txt").first))
        .to match(/Total Estimated IC Cost/)
    end

    xit "MemberCount produces output" do
      output_path = "#{ENV["TEST_TMP"]}/member_count_output"

      phctl("report", "member-counts", fixture("freq.txt"), output_path)
      expect(File.size("#{output_path}/member_counts_#{Date.today}.tsv")).to be > 0
    end

    it "Overlap produces output" do
      phctl(*%w[report overlap umich])

      expect(File.size("#{ENV["TEST_TMP"]}/overlap_report_remote/umich-hathitrust-member-data/analysis/overlap_umich_#{Date.today}.tsv.gz")).to be > 0
    end

    xcontext "shared print reports" do
      it "EligibleCommitments produces output" do
        phctl(*%w[report eligible-commitments 1])

        expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/shared_print_reports/eligible_commitments_*").first))
          .to match(/^organization/)
      end

      it "UncommittedHoldings produces output" do
        phctl(*%w[report uncommitted-holdings --organization umich])

        expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/shared_print_reports/uncommitted_holdings_umich_*").first))
          .to match(/^organization/)
      end

      it "RareUncommittedCounts produces output" do
        phctl(*%w[report rare-uncommitted-counts --max-h 1])

        expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/shared_print_reports/rare_uncommitted_counts_*").first))
          .to match(/^number of holding libraries/)
      end

      it "OCLCRegistration produces output" do
        phctl(*%w[report oclc-registration umich])
        expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/oclc_registration_umich_*").first))
          .to match(/^local_oclc/)
      end

      it "SharedPrintNewlyIngested produces output" do
        phctl(*%w[report shared-print-newly-ingested --start_date=2021-01-01 --ht_item_ids_file=spec/fixtures/shared_print_newly_ingested_ht_items.tsv --inline])
        snir = "sp_newly_ingested_report"
        glob = Dir.glob("#{ENV["TEST_TMP"]}/#{snir}/#{snir}_*").first
        rpt_out = File.read(glob)
        expect(rpt_out).to match(/contributor/)
      end

      it "SharedPrintPhaseCount produces output" do
        cluster_tap_save build(:commitment, phase: 0)
        phctl(*%w[report shared-print-phase-count --phase 0])
        glob = Dir.glob("#{ENV["TEST_TMP"]}/local_reports/sp_phase0_count/sp_phase0_count_*").first
        lines = File.read(glob).split("\n")
        expect(lines.count).to eq 2 # 1 header, 1 body
      end
    end
  end

  describe "Parse" do
    it "parses holdings xml files" do
      cmd_array = [
        "parse",
        "parse-holdings-xml",
        "--organization", "foo",
        "--files", fixture("exlibris_mon_in.xml"), fixture("exlibris_ser_in.xml"),
        "--output-dir", ENV["TEST_TMP"]
      ]
      phctl(*cmd_array)

      date = Date.today.strftime("%Y%m%d")
      mon_output = File.join(ENV["TEST_TMP"], "foo_mon_full_#{date}.tsv")
      ser_output = File.join(ENV["TEST_TMP"], "foo_ser_full_#{date}.tsv")

      expect(FileUtils.compare_file(mon_output, fixture("exlibris_mon_out.tsv"))).to be_truthy
      expect(FileUtils.compare_file(ser_output, fixture("exlibris_ser_out.tsv"))).to be_truthy
    end
  end

  describe "Backup holdings" do
    it "generates the expected backup file with the expected number of holdings" do
      # Generate holdings
      holdings_count = 3
      1.upto(holdings_count) do
        load_test_data(build(:holding, organization: "umich", mono_multi_serial: "mon"))
      end

      # Set up expected output file and expect it to not exist initially
      date = Time.new.strftime("%Y%m%d")
      expected_output_path = File.join(Settings.backup_dir, "umich_mon_full_#{date}_backup.ndj")
      expect(File.exist?(expected_output_path)).to be false

      # Run the backup command,
      # and expect to see the generated backup file with the expected record count.
      cmd_array = ["backup", "holdings", "--organization", "umich", "--mono-multi-serial", "mon"]
      phctl(*cmd_array)
      expect(File.exist?(expected_output_path)).to be true
      lines = File.read(expected_output_path).split("\n")
      expect(lines.count).to eq holdings_count
    end
  end

  describe "Scrub" do
    it "'scrub x' loads records and produces output for org x" do
      # Needs a bit of setup.
      local_d = "#{ENV["TEST_TMP"]}/local_member_data/umich-hathitrust-member-data/print holdings/#{Time.new.year}/"
      remote_d = "#{ENV["TEST_TMP"]}/remote_member_data/umich-hathitrust-member-data/print holdings/#{Time.new.year}/"
      logfile = File.join(remote_d, "umich_mon_#{Time.new.strftime("%Y%m%d")}.log")
      FileUtils.mkdir_p(remote_d)
      FileUtils.cp("spec/fixtures/umich_mon_full_20220101.tsv", remote_d)
      # Verify precondition:
      expect(File.exist?(logfile)).to be false
      expect(File.exist?(local_d)).to be false
      # Actual tests:
      # Only set force_holding_loader_cleanup_test to true in testing.
      expect { phctl(*%w[scrub umich --force_holding_loader_cleanup_test --force]) }.to change { Clusterable::Holding.table.count }.by(6)
      expect(File.exist?(logfile)).to be true
      expect(File.exist?(local_d)).to be true
    end
  end
end
