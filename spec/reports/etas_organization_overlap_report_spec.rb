# frozen_string_literal: true

require "spec_helper"
require "reports/etas_organization_overlap_report"

RSpec.describe Reports::EtasOrganizationOverlapReport do
  let(:tmp_local) { Settings.local_report_path }
  let(:tmp_pers) { Settings.etas_overlap_reports_path }
  let(:tmp_rmt) { Settings.etas_overlap_reports_remote_path }

  include_context "with tables for holdings"

  describe "#initialize" do
    it "makes the directory if it doesn't exist" do
      rpt = described_class.new
      expect(rpt.persistent_report_path).to eq(tmp_pers)
      expect(File).to exist(tmp_pers)
      expect(File).to exist(rpt.local_report_path)
    end
  end

  describe "#report_for_org" do
    it "gives us a filehandle for the org" do
      rpt = described_class.new
      expect(rpt.report_for_org("smu")).to be_a(File)
      expect(rpt.report_for_org("smu").path)
        .to eq("#{tmp_local}/etas_overlap_smu_#{rpt.date_of_report}.tsv")
    end

    it "gives us a 'nonus' filehandle for non-us orgs" do
      rpt = described_class.new
      expect(rpt.report_for_org("uct").path)
        .to eq("#{tmp_local}/etas_overlap_uct_#{rpt.date_of_report}_nonus.tsv")
    end

    it "has a header" do
      rpt = described_class.new
      rpt.report_for_org("smu").close
      expect(File.readlines(rpt.report_for_org("smu").path)).to eq([rpt.header + "\n"])
    end
  end

  describe "#gzip_report" do
    let(:h) { build(:holding) }
    let(:ht) { build(:ht_item, ocns: [h.ocn]) }

    before(:each) do
      load_test_data(h, ht)
    end

    it "gzips and prepends file name" do
      rpt = described_class.new
      rpt.run
      gz = rpt.gzip_report(rpt.report_for_org(h.organization))
      expect(File.path(gz))
        .to eq("#{tmp_local}/etas_overlap_#{h.organization}_#{rpt.date_of_report}.tsv.gz")
    end
  end

  describe "#run" do
    let(:h) { build(:holding) }
    let(:h2) { build(:holding, organization: "ualberta") }
    let(:ht) { build(:ht_item, ocns: [h.ocn], access: "deny") }
    let(:ht2) { build(:ht_item, ocns: [h.ocn], access: "allow", rights: "pd") }
    let(:orgs) { [h.organization, h2.organization] }

    before(:each) do
      load_test_data(h, h2, ht, ht2)
    end

    it "has a file for each organization" do
      rpt = described_class.new
      rpt.run
      orgs.each do |org|
        expect(rpt.reports.keys).to include(org)
      end
    end

    it "only has a file for the organization given" do
      load_test_data(build(:holding, ocn: h2.ocn))
      rpt = described_class.new(orgs.last)
      rpt.run
      expect(rpt.reports.keys).to eq([orgs.last])
    end

    it "has a line for each ht_item in the holding organization rpt" do
      rpt = described_class.new
      rpt.run
      f = rpt.report_for_org(h.organization)
      f.close
      lines = File.open(f.path).to_a
      expect(lines.size).to eq(3)
    end

    it "has 8 columns in the report" do
      rpt = described_class.new
      rpt.run
      orgs.each do |org|
        rpt.report_for_org(org).close
        lines = File.open(rpt.report_for_org(org).path).to_a.map { |x| x.split("\t") }
        expect(lines.map(&:size)).to all(be == 8)
      end
    end

    it "has 1 line with empty rights/access for holdings on clusters without HTItems" do
      rpt = described_class.new
      rpt.run
      f = rpt.report_for_org(h2.organization)
      f.close
      lines = File.open(rpt.report_for_org(h2.organization).path).to_a
      expect(lines.size).to eq(2)
      rec = lines.last.split("\t")
      expect(rec[3]).to eq("")
      expect(rec[7]).to eq("\n")
    end

    it "has records for holdings that don't match HTItems" do
      no_match = build(:holding, mono_multi_serial: "mpm", enum_chron: "V.1")
      load_test_data(
        no_match,
        build(:ht_item, bib_fmt: "BK", ocns: [no_match.ocn], enum_chron: "V.2")
      )

      rpt = described_class.new.tap(&:run)
      rpt.report_for_org(no_match.organization).close
      recs = File.readlines(rpt.report_for_org(no_match.organization).path)
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
      rpt = described_class.new(h1.organization)
      rpt.run
      rpt.report_for_org(h1.organization).close
      expect(File.readlines(rpt.report_for_org(h1.organization).path).count)
        .to eq(2)
    end

    it "writes only 1 match record" do
      ht = build(:ht_item, ocns: [h1.ocn], bib_fmt: "SE", enum_chron: "V.3")
      load_test_data(ht)
      rpt = described_class.new(h1.organization)
      rpt.run
      rpt.report_for_org(h1.organization).close
      recs = File.readlines(rpt.report_for_org(h1.organization).path)
      expect(recs.count).to eq(2)
      expect(recs.last.chomp).to eq([h1.ocn, h1.local_id, h1.mono_multi_serial, ht.rights,
        ht.access, ht.ht_bib_key, ht.item_id,
        ht.enum_chron].join("\t"))
    end

    it "writes only the 1 record that matches" do
      ht = build(:ht_item, ocns: [h1.ocn], bib_fmt: "BK", enum_chron: "V.2")
      load_test_data(ht)
      rpt = described_class.new(h1.organization)
      rpt.run
      rpt.report_for_org(h1.organization).close
      recs = File.readlines(rpt.report_for_org(h1.organization).path)
      expect(recs.count).to eq(2)
      expect(recs.last.chomp).to eq([h1.ocn, h1.local_id, h1.mono_multi_serial, ht.rights,
        ht.access, ht.ht_bib_key, ht.item_id,
        ht.enum_chron].join("\t"))
    end
  end

  describe "#move_reports" do
    let(:h) { build(:holding) }
    let(:ht) { build(:ht_item, ocns: [h.ocn]) }

    before(:each) do
      load_test_data(h, ht)
    end

    it "moves the gzipped report to the persistent storage path" do
      rpt = described_class.new(h.organization)
      rpt.run
      rpt.move_reports
      persistent_file = "#{tmp_pers}/" \
        "#{File.basename(rpt.report_for_org(h.organization))}.gz"
      expect(File.exist?(persistent_file)).to be true
    end

    it "moves the gzipped report to the \"remote\" path" do
      rpt = described_class.new(h.organization)
      rpt.run
      rpt.move_reports
      remote_file = "#{tmp_rmt}/#{h.organization}-hathitrust-member-data/analysis/" \
        "#{File.basename(rpt.report_for_org(h.organization))}.gz"
      expect(File.exist?(remote_file)).to be true
    end
  end

  describe "#rclone_move" do
    it "provides the proper system call for rclone" do
      rpt = described_class.new
      expect(rpt.rclone_move(File.open("test_file", "w"), "umich"))
        .to eq(["rclone", "--config", Settings.rclone_config_path, "move", "test_file",
          "#{tmp_rmt}/umich-hathitrust-member-data/analysis"])
    end
  end
end
