# frozen_string_literal: true

require "spec_helper"
require "phctl"

RSpec.describe "phctl integration" do
  def phctl(*args)
    PHCTL::PHCTL.start(args)
  end

  before(:each) do
    Cluster.each(&:delete)
  end

  describe "load" do
    describe "commitments" do
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

    it "HtItems loads hathifiles" do
      expect { phctl("load", "ht_items", fixture("hathifile_sample.txt")) }
        .to change { cluster_count(:ht_items) }.by(5)
    end

    it "Concordance loads concordance diffs" do
      Settings.concordance_path = fixture("concordance")
      expect { phctl(*%w[load concordance 2022-08-01]) }
        .to change { cluster_count(:ocn_resolutions) }.by(5)
    end

    it "Holdings loads holdings" do
      expect { phctl("load", "holdings", fixture("umich_fake_testdata.ndj")) }
        .to change { cluster_count(:holdings) }.by(10)
    end

    it "ClusterFile loads json clusters" do
      expect { phctl("load", "cluster_file", fixture("cluster_2503661.json")) }
        .to change { Cluster.count }.by(1)
    end
  end

  describe "Cleanup" do
    it "Holdings removes old holdings" do
      phctl("load", "holdings", fixture("umich_fake_testdata.ndj"))
      expect { phctl(*%w[cleanup holdings umich 2022-01-01]) }
        .to change { cluster_count(:holdings) }.by(-10)
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
      Jobs::Concordance::Delta.new.perform("concordance_sample.txt", "concordance_sample_2.txt")
      expect(File.size("#{diffs_path}/comm_diff_#{Date.today}.txt.adds")).to be > 0
      expect(File.size("#{diffs_path}/comm_diff_#{Date.today}.txt.deletes")).to be > 0
    end
  end

  # SharedPrintOps - integration tests are in the respective SharedPrint class

  describe "Report" do
    before(:each) do
      phctl("load", "cluster_file", fixture("cluster_2503661.json"))
    end

    it "CostReport produces output" do
      phctl(*%w[report costreport])
      year = Time.new.year.to_s
      expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/cost_reports/#{year}/*").first))
        .to match(/Target cost: 9999/)
    end

    it "Estimate produces output" do
      phctl("report", "estimate", fixture("ocn_list.txt"))

      expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/estimates/ocn_list-estimate-*.txt").first))
        .to match(/Total Estimated IC Cost/)
    end

    it "MemberCount produces output" do
      output_path = "#{ENV["TEST_TMP"]}/member_count_output"

      phctl("report", "member-counts", fixture("freq.txt"), output_path)
      expect(File.size("#{output_path}/member_counts_#{Date.today}.tsv")).to be > 0
    end

    it "EtasOverlap produces output" do
      phctl(*%w[report etas-overlap umich])

      expect(File.size("#{ENV["TEST_TMP"]}/etas_overlap_report_remote/umich-hathitrust-member-data/analysis/etas_overlap_umich_#{Date.today}.tsv.gz")).to be > 0
    end

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
  end

  describe "Scrub" do
    it "'scrub x' loads records and produces output for org x" do
      # Needs a bit of setup.
      local_d = "#{ENV["TEST_TMP"]}/local_member_data/umich-hathitrust-member-data/print\ holdings/#{Time.new.year}/"
      remote_d = "#{ENV["TEST_TMP"]}/remote_member_data/umich-hathitrust-member-data/print\ holdings/#{Time.new.year}/"
      logfile = File.join(remote_d, "umich_mon_#{Time.new.strftime("%Y%m%d")}.log")
      FileUtils.mkdir_p(remote_d)
      FileUtils.cp("spec/fixtures/umich_mon_full_20220101.tsv", remote_d)
      # Verify precondition:
      expect(File.exist?(logfile)).to be false
      expect(File.exist?(local_d)).to be false
      # Actual tests:
      # Only set force_holding_loader_cleanup_test to true in testing.
      expect { phctl(*%w[scrub umich --force_holding_loader_cleanup_test --force]) }.to change { cluster_count(:holdings) }.by(6)
      expect(File.exist?(logfile)).to be true
      expect(File.exist?(local_d)).to be true
    end
  end
end
