# frozen_string_literal: true

require "spec_helper"
require "phctl"

RSpec.describe "phctl integration" do
  def phctl(*args)
    PHCTL::PHCTL.start(args)
  end

  include_context "with tables for holdings"

  describe "load" do
    it "Holdings loads holdings" do
      expect { phctl("load", "holdings", fixture("umich_fake_testdata.ndj")) }
        .to change { Clusterable::Holding.table.count }.by(10)
    end

    describe "concordance" do
      around(:each) do |example|
        saved_concordance_path = Settings.concordance_path
        Settings.concordance_path = fixture("concordance")
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
    let(:output) { "#{ENV["TEST_TMP"]}/concordance_output" }

    def cleanup(output)
      File.unlink(output) if File.exist?(output)
      File.unlink("#{output}.log") if File.exist?("#{output}.log")
    end

    before(:each) { cleanup(output) }
    after(:each) { cleanup(output) }

    it "Validate produces output and log" do
      phctl("concordance", "validate", fixture("concordance_sample.txt"), output)
      expect(File.size(output)).to be > 0
      expect(File).to exist("#{output}.log")
    end

    it "Validate runs to completion when there are cycles in the concordance" do
      expect { phctl("concordance", "validate", fixture("concordance/raw/cycles.tsv"), output) }
        .not_to raise_error
      expect(File).to exist("#{output}.log")
    end

    it "Validate runs to completion when there are multiple terminal OCNs in the concordance" do
      expect { phctl("concordance", "validate", fixture("concordance/raw/multiple_terminal.tsv"), output) }
        .not_to raise_error
      expect(File).to exist("#{output}.log")
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

  describe "Report" do
    include_context "with mocked solr response"
    include_context "with complete data for one cluster"

    it "cost report workflow produces output" do
      # item counts match what we specify
      phctl(*%w[workflow costreport --ht-item-count 999 --ht-item-pd-count 123 --test-mode])
      year = Time.new.year.to_s

      costreport = File.read(Dir.glob("#{ENV["TEST_TMP"]}/cost_reports/#{year}/*").first)
      expect(costreport).to match(/Num volumes: 999/)
      expect(costreport).to match(/Num pd volumes: 123/)
    end

    it "cost report workflow produces output without given item count or pd count" do
      # we start with one pd item from "with complete data for one cluster"; add some more:
      8.times { insert_htitem(build(:ht_item, rights: "ic")) }
      4.times { insert_htitem(build(:ht_item, rights: "pd")) }

      phctl(*%w[workflow costreport --test-mode])
      year = Time.new.year.to_s

      costreport = File.read(Dir.glob("#{ENV["TEST_TMP"]}/cost_reports/#{year}/*").first)
      # item counts match what we put in hathifiles table
      expect(costreport).to match(/Num volumes: 13/)
      expect(costreport).to match(/Num pd volumes: 5/)
    end

    it "Estimate produces output" do
      phctl("workflow", "estimate", fixture("ocn_list.txt"), "--test-mode")

      expect(File.read(Dir.glob("#{ENV["TEST_TMP"]}/estimates/ocn_list-estimate-*.txt").first))
        .to match(/Total Estimated IC Cost/)
    end

    it "Overlap produces output" do
      phctl(*%w[workflow overlap umich --test-mode])

      expect(File.size("#{ENV["TEST_TMP"]}/overlap_report_remote/umich-hathitrust-member-data/analysis/overlap_umich_#{Date.today}.tsv.gz")).to be > 0
    end

    it "Overlap with matching members counts produces output" do
      phctl(*%w[workflow overlap umich --test-mode --matching-members-count])

      expect(File.size("#{ENV["TEST_TMP"]}/overlap_report_remote/umich-hathitrust-member-data/analysis/overlap_umich_#{Date.today}.tsv.gz")).to be > 0
    end

    context "with mocked solr rights search" do
      before(:each) do
        mock_solr_rights_search(File.open(fixture("solr_response.json")))
      end

      it "deposit holdings analysis produces output" do
        phctl(*%w[workflow deposit_holdings_analysis --test-mode])

        expect(File.size("#{ENV["TEST_TMP"]}/overlap_reports/deposit_holdings_analysis_#{Date.today}.tsv.gz")).to be > 0
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

    context "Slack notification" do
      include_context "with mocked slack API endpoint"

      it "posts a Slack notification on successful load" do
        remote_d = "#{ENV["TEST_TMP"]}/remote_member_data/umich-hathitrust-member-data/print holdings/#{Time.new.year}/"
        FileUtils.mkdir_p(remote_d)
        FileUtils.cp("spec/fixtures/umich_mon_full_20220101.tsv", remote_d)

        stub = stub_slack_webhook(a_string_including("umich")
          .and(a_string_including("mon"))
          .and(a_string_including("6 records loaded")))

        phctl(*%w[scrub umich --force_holding_loader_cleanup_test --force])

        expect(stub).to have_been_requested.once
      end

      it "posts a Slack notification when a file is rejected by the diff check" do
        remote_d = "#{ENV["TEST_TMP"]}/remote_member_data/umich-hathitrust-member-data/print holdings/#{Time.new.year}/"
        FileUtils.mkdir_p(remote_d)
        FileUtils.cp("spec/fixtures/umich_mon_full_20220101.tsv", remote_d)

        loaded_d = "#{ENV["TEST_TMP"]}/scrub_data/umich/loaded"
        FileUtils.mkdir_p(loaded_d)
        File.open(File.join(loaded_d, "umich_mon_1.ndj"), "w") { |f| 20.times { |i| f.puts i } }

        stub = stub_slack_webhook(a_string_including("umich")
          .and(a_string_including("rejected"))
          .and(a_string_including("Diff too big"))
          .and(a_string_including("umich_mon_full_20220101.tsv"))
          .and(a_string_including("Line diff too great")))
        # phctl scrub calls `exit 1` in case of error
        expect {
          phctl(*%w[scrub umich])
        }.to raise_error(SystemExit)
        expect(stub).to have_been_requested.once
      end
    end
  end

  describe "Scrub File" do
    it "exits with status 1 in case of error" do
      expect {
        phctl(*%w[scrub_file umich so_such_file])
      }.to raise_error(SystemExit)
    end
  end
end
