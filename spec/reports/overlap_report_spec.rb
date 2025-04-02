# frozen_string_literal: true

require "solr_batch"
require "spec_helper"
require "reports/overlap_report"

RSpec.describe Reports::OverlapReport do
  let(:tmp_local) { Settings.local_report_path }
  let(:tmp_pers) { Settings.overlap_reports_path }
  let(:tmp_rmt) { Settings.overlap_reports_remote_path }

  include_context "with tables for holdings"
  include_context "with mocked solr response"

  describe "#initialize" do
    it "makes the directory if it doesn't exist" do
      rpt = described_class.new("umich")
      expect(rpt.persistent_report_path).to eq(tmp_pers)
      expect(File).to exist(tmp_pers)
      expect(File).to exist(rpt.local_report_path)
    end
  end

  describe "#report" do
    it "gives us a filehandle for the org" do
      rpt = described_class.new("smu")
      expect(rpt.report).to be_a(File)
      expect(rpt.report.path)
        .to eq("#{tmp_local}/overlap_smu_#{rpt.date_of_report}.tsv")
    end

    it "gives us a 'nonus' filehandle for non-us orgs" do
      rpt = described_class.new("uct")
      expect(rpt.report.path)
        .to eq("#{tmp_local}/overlap_uct_#{rpt.date_of_report}_nonus.tsv")
    end

    it "has a header" do
      rpt = described_class.new("smu")
      rpt.report.close
      expect(File.readlines(rpt.report.path)).to eq([rpt.header + "\n"])
    end
  end

  describe "#gzip_report" do
    it "gzips and prepends file name" do
      rpt = described_class.new("umich")
      rpt.run
      gz = rpt.gzip_report(rpt.report)
      expect(File.path(gz))
        .to eq("#{tmp_local}/overlap_umich_#{rpt.date_of_report}.tsv.gz")
    end
  end

  describe "#run" do
    let(:h) { build(:holding, organization: "umich") }
    let(:h2) { build(:holding, organization: "ualberta") }
    let(:ht) { build(:ht_item, ocns: [h.ocn], access: "deny") }
    let(:ht2) { build(:ht_item, ocns: [h.ocn], access: "allow", rights: "pd") }
    let(:orgs) { [h.organization, h2.organization] }

    before(:each) do
      load_test_data(h, h2, ht, ht2)
      mock_solr_oclc_search(solr_response_for(ht, ht2))
    end

    it "has a line for each ht_item in the holding organization rpt" do
      rpt = described_class.new(h.organization)
      rpt.run
      f = rpt.report
      f.close
      lines = File.open(f.path).to_a
      expect(lines.size).to eq(3)
    end

    it "has 8 columns in the report" do
      rpt = described_class.new(h.organization)
      rpt.run
      rpt.report.close
      lines = File.open(rpt.report.path).to_a.map { |x| x.split("\t") }
      expect(lines.map(&:size)).to all(be == 8)
    end

    it "has 1 line with empty rights/access for holdings on clusters without HTItems" do
      rpt = described_class.new(h2.organization)
      rpt.run
      f = rpt.report
      f.close
      lines = File.open(rpt.report.path).to_a
      expect(lines.size).to eq(2)
      rec = lines.last.split("\t")
      expect(rec[3]).to eq("")
      expect(rec[7]).to eq("\n")
    end

    it "has records for holdings that don't match HTItems" do
      # holding has enumchron V.1
      no_match = build(:holding, mono_multi_serial: "mpm", enum_chron: "V.1")
      # ht item has enumchron V.2 but same OCN -- shouldn't match holding
      ht_item = build(:ht_item, bib_fmt: "BK", ocns: [no_match.ocn], enum_chron: "V.2")

      load_test_data(no_match, ht_item)

      mock_solr_oclc_search(solr_response_for(ht_item))

      # both are on the same catalog record but won't match
      rpt = described_class.new(no_match.organization).tap(&:run)
      rpt.report.close
      recs = File.readlines(rpt.report.path)
      expected_rec = [no_match.ocn, no_match.local_id, no_match.mono_multi_serial,
        "", "", "", "", ""].join("\t")
      expect(recs.find { |r| r.match?(/^#{no_match.ocn}/) }).to eq(expected_rec + "\n")
    end
  end

  context "when holdings have the same id" do
    let(:h1) { build(:holding, mono_multi_serial: "mpm", enum_chron: "V.1") }
    let(:h2) do
      build(:holding, mono_multi_serial: "mpm", ocn: h1.ocn,
        organization: h1.organization, local_id: h1.local_id, enum_chron: "V.2")
    end

    before(:each) do
      load_test_data(h1, h2)
    end

    it "writes only 1 no-match record" do
      mock_solr_oclc_search(solr_response_for)
      rpt = described_class.new(h1.organization)
      rpt.run
      rpt.report.close
      expect(File.readlines(rpt.report.path).count)
        .to eq(2)
    end

    it "writes only 1 match record" do
      ht = build(:ht_item, ocns: [h1.ocn], bib_fmt: "SE", enum_chron: "V.3")
      load_test_data(ht)
      mock_solr_oclc_search(solr_response_for(ht))
      rpt = described_class.new(h1.organization)
      rpt.run
      rpt.report.close
      recs = File.readlines(rpt.report.path)
      expect(recs.count).to eq(2)
      expect(recs.last.chomp).to eq([h1.ocn, h1.local_id, h1.mono_multi_serial, ht.rights,
        ht.access, ht.ht_bib_key, ht.item_id,
        ht.enum_chron].join("\t"))
    end

    it "writes only the 1 record that matches" do
      ht = build(:ht_item, ocns: [h1.ocn], bib_fmt: "BK", enum_chron: "V.2")
      load_test_data(ht)
      mock_solr_oclc_search(solr_response_for(ht))
      rpt = described_class.new(h1.organization)
      rpt.run
      rpt.report.close
      recs = File.readlines(rpt.report.path)
      expect(recs.count).to eq(2)
      expect(recs.last.chomp).to eq([h1.ocn, h1.local_id, h1.mono_multi_serial, ht.rights,
        ht.access, ht.ht_bib_key, ht.item_id,
        ht.enum_chron].join("\t"))
    end
  end

  describe "#move_report" do
    it "moves the gzipped report to the persistent storage path" do
      rpt = described_class.new("umich")
      rpt.run
      rpt.move_report
      persistent_file = "#{tmp_pers}/" \
        "#{File.basename(rpt.report)}.gz"
      expect(File.exist?(persistent_file)).to be true
    end

    it "moves the gzipped report to the \"remote\" path" do
      rpt = described_class.new("umich")
      rpt.run
      rpt.move_report
      remote_file = "#{tmp_rmt}/umich-hathitrust-member-data/analysis/" \
        "#{File.basename(rpt.report)}.gz"
      expect(File.exist?(remote_file)).to be true
    end
  end

  describe "#rclone_move" do
    it "provides the proper system call for rclone" do
      rpt = described_class.new("umich")
      expect(rpt.rclone_move(File.open("test_file", "w"), "umich"))
        .to eq(["rclone", "--config", Settings.rclone_config_path, "move", "test_file",
          "#{tmp_rmt}/umich-hathitrust-member-data/analysis"])
    end
  end
end
