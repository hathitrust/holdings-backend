# frozen_string_literal: true

require "spec_helper"
require "sidekiq_jobs"
require "sidekiq/testing"

RSpec.describe "Jobs" do
  def cluster_count(field)
    Cluster.all.map { |c| c.public_send(field).count }.reduce(0, :+)
  end

  before(:each) do
    Cluster.each(&:delete)
  end

  describe "Load" do
    it "Commitments loads json file of commitments" do
      expect { Jobs::Load::Commitments.new.perform(fixture("sp_commitment.json")) }
        .to change { cluster_count(:commitments) }.by(1)
    end

    it "HtItems loads hathifiles" do
      expect { Jobs::Load::HtItems.new.perform(fixture("hathifile_sample.txt")) }
        .to change { cluster_count(:ht_items) }.by(5)
    end

    it "Concordance loads concordance diffs" do
      old_path = Settings.concordance_path
      begin
        Settings.concordance_path = fixture("concordance")
        expect { Jobs::Load::Concordance.new.perform("2022-08-01") }
          .to change { cluster_count(:ocn_resolutions) }.by(5)
      ensure
        Settings.concordance_path = old_path
      end
    end

    it "Holdings loads holdings" do
      expect { Jobs::Load::Holdings.new.perform(fixture("umich_fake_testdata.ndj")) }
        .to change { cluster_count(:holdings) }.by(10)
    end

    it "ClusterFile loads json clusters" do
      expect { Jobs::Load::ClusterFile.new.perform(fixture("cluster_2503661.json")) }
        .to change { Cluster.count }.by(1)
    end
  end

  describe "Cleanup" do
    it "Holdings removes old holdings" do
      Jobs::Load::Holdings.new.perform(fixture("umich_fake_testdata.ndj"))
      expect { Jobs::Cleanup::Holdings.new.perform("umich", "2022-01-01") }
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
      output = "/tmp/concordance_output"
      cleanup(output)

      begin
        Jobs::Concordance::Validate.new.perform(input, output)
        expect(File.size(output)).to be > 0
        expect(File).to exist("#{output}.log")
      ensure
        cleanup(output)
      end
    end

    it "Delta produces adds and deletes" do
      validated_path = "/tmp/concordance/validated"
      diffs_path = "/tmp/concordance/diffs"

      FileUtils.mkdir_p(validated_path)
      FileUtils.mkdir_p(diffs_path)
      FileUtils.cp(fixture("concordance_sample.txt"), validated_path)
      FileUtils.cp(fixture("concordance_sample_2.txt"), validated_path)
      Jobs::Concordance::Delta.new.perform("concordance_sample.txt", "concordance_sample_2.txt")
      expect(File.size("#{diffs_path}/comm_diff_#{Date.today}.txt.adds")).to be > 0
      expect(File.size("#{diffs_path}/comm_diff_#{Date.today}.txt.deletes")).to be > 0
    ensure
      FileUtils.rm_rf("/tmp/concordance")
    end
  end

  # SharedPrintOps - integration tests are in the respective SharedPrint class

  describe "Report" do
    before(:each) do
      Jobs::Load::ClusterFile.new.perform(fixture("cluster_2503661.json"))
    end

    it "CostReport produces output" do
      Jobs::Report::CostReport.new.perform(nil, nil)

      expect(File.read(Dir.glob("/tmp/cost_reports/*").first))
        .to match(/Target cost: 9999/)
    end

    it "Estimate produces output" do
      Jobs::Report::Estimate.new.perform(fixture("ocn_list.txt"))

      expect(File.read(Dir.glob("/tmp/estimates/ocn_list-estimate-*.txt").first))
        .to match(/Total Estimated IC Cost/)
    end

    it "MemberCount produces output" do
      output_path = "/tmp/member_count_output"
      FileUtils.rm_rf(output_path) if File.exist?(output_path)

      begin
        Jobs::Report::MemberCounts.new.perform(fixture("freq.txt"), output_path)
        expect(File.size("#{output_path}/member_counts_#{Date.today}.tsv")).to be > 0
      ensure
        FileUtils.rm_rf(output_path)
      end
    end

    it "EtasOverlap produces output" do
      Jobs::Report::EtasOverlap.new.perform("umich")

      expect(File.size("/tmp/etas_overlap_report_remote/umich-hathitrust-member-data/analysis/etas_overlap_umich_#{Date.today}.tsv.gz")).to be > 0
    end

    it "EligibleCommitments produces output" do
      Jobs::Report::EligibleCommitments.new.perform([1])

      expect(File.read(Dir.glob("/tmp/shared_print_reports/eligible_commitments_*").first))
        .to match(/^organization/)
    end

    it "UncommittedHoldings produces output" do
      Jobs::Report::UncommittedHoldings.new.perform(organization: ["umich"])

      expect(File.read(Dir.glob("/tmp/shared_print_reports/uncommitted_holdings_umich_*").first))
        .to match(/^organization/)
    end

    it "RareUncommittedCounts produces output" do
      Jobs::Report::RareUncommittedCounts.new.perform(max_h: 1)

      expect(File.read(Dir.glob("/tmp/shared_print_reports/rare_uncommitted_counts_*").first))
        .to match(/^number of holding libraries/)
    end
  end

  xit "failed job goes to retry queue"
  xit "repeatedly failed job reports to slack"
  xit "successful job reports to slack"
end
