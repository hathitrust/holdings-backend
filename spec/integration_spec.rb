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

    it "HtItems creates clusters with ocns in hathifile" do
      expect { phctl("load", "ht_items", fixture("hathifile_sample.txt")) }
        .to change { Cluster.count }.by(5)
    end

    xit "Concordance loads concordance diffs" do
      Settings.concordance_path = fixture("concordance")
      expect { phctl(*%w[load concordance 2022-08-01]) }
        .to change { cluster_count(:ocn_resolutions) }.by(5)
    end

    it "Holdings loads holdings" do
      expect { phctl("load", "holdings", fixture("umich_fake_testdata.ndj")) }
        .to change { Clusterable::Holding.table.count }.by(10)
    end

    xit "ClusterFile loads json clusters" do
      expect { phctl("load", "cluster_file", fixture("cluster_2503661.json")) }
        .to change { Cluster.count }.by(1)
    end
  end

  xdescribe "Cleanup" do
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
      # Data from spec/fixtures/cluster_2503661.json, without commitments
      
      Cluster.create(ocns: [8637629])
      insert_htitem(build(:ht_item,
                          ocns: [2503661],
                          item_id: "nyp.33433082421565",
                          ht_bib_key: 8638629,
                          rights: "pd",
                          bib_fmt: "BK",
                          enum_chron: "",
                          n_enum: "",
                          n_chron: "",
                          access: "allow",
                          billing_entity: "nypl",
                          collection_code: "NYP",
                          n_enum_chron: ""))

      holdings = [
        {
          "enum_chron"=> "",
          "n_enum"=> "",
          "n_chron"=> "",
          "ocn"=> 2503661,
          "local_id"=> "000238264",
          "organization"=> "upenn",
          "status"=> "CH",
          "condition"=> "",
          "date_received"=> Date.parse("2018-08-10"),
          "mono_multi_serial"=> "spm",
          "issn"=> "",
          "gov_doc_flag"=> false,
          "uuid"=> "bab56a32-cf07-4059-92eb-a213012acf59",
          "n_enum_chron"=> ""
        },
        {
          "enum_chron"=> "",
          "n_enum"=> "",
          "n_chron"=> "",
          "ocn"=> 2503661,
          "local_id"=> "188946",
          "organization"=> "umich",
          "status"=> "CH",
          "condition"=> "",
          "date_received"=> Date.parse("2020-05-28"),
          "mono_multi_serial"=> "spm",
          "issn"=> "",
          "gov_doc_flag"=> false,
          "uuid"=> "2ab58107-36a8-4ecc-945d-26e3327f9d18",
          "n_enum_chron"=> ""
        },
        {
          "enum_chron"=> "",
          "n_enum"=> "",
          "n_chron"=> "",
          "ocn"=> 2503661,
          "local_id"=> "2503661",
          "organization"=> "smu",
          "condition"=> "",
          "date_received"=> Date.parse("2019-07-19"),
          "mono_multi_serial"=> "spm",
          "issn"=> "",
          "gov_doc_flag"=> false,
          "uuid"=> "1a2fc3cb-ffb3-4f7a-b8fc-05b6c3c3b179",
          "n_enum_chron"=> ""
        }
      ]

      holdings.each { |h| Clusterable::Holding.table.insert(h) }
    end

    it "CostReport produces output" do
      phctl(*%w[report costreport])
      year = Time.new.year.to_s
      expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/cost_reports/#{year}/*").first))
        .to match(/Target cost: 9999/)
    end

    xit "Estimate produces output" do
      phctl("report", "estimate", fixture("ocn_list.txt"))

      expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/estimates/ocn_list-estimate-*.txt").first))
        .to match(/Total Estimated IC Cost/)
    end

    xit "MemberCount produces output" do
      output_path = "#{ENV["TEST_TMP"]}/member_count_output"

      phctl("report", "member-counts", fixture("freq.txt"), output_path)
      expect(File.size("#{output_path}/member_counts_#{Date.today}.tsv")).to be > 0
    end

    xit "EtasOverlap produces output" do
      phctl(*%w[report etas-overlap umich])

      expect(File.size("#{ENV["TEST_TMP"]}/etas_overlap_report_remote/umich-hathitrust-member-data/analysis/etas_overlap_umich_#{Date.today}.tsv.gz")).to be > 0
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
