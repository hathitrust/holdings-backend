# frozen_string_literal: true

require "spec_helper"
require "pp"
require "reports/etas_organization_overlap_report"

RSpec.describe Reports::EtasOrganizationOverlapReport do
  let(:h) { build(:holding) }
  let(:h2) { build(:holding, organization: "ualberta") }
  let(:ht) { build(:ht_item, ocns: [h.ocn], access: "deny") }
  let(:ht2) { build(:ht_item, ocns: [h.ocn], access: "allow", rights: "pd") }
  let(:tmp_dir) { "tmp_reports_dir" }
  let(:orgs) { [h.organization, h2.organization] }

  before(:each) do
    Cluster.each(&:delete)
    Clustering::ClusterHolding.new(h).cluster.tap(&:save)
    Clustering::ClusterHolding.new(h2).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht2).cluster.tap(&:save)
    Settings.etas_overlap_reports_path = tmp_dir
    FileUtils.rm_rf(tmp_dir)
  end

  after(:each) do
    FileUtils.rm_rf(tmp_dir)
  end

  describe "#initialize" do
    it "makes the directory if it doesn't exist" do
      rpt = described_class.new
      expect(rpt.report_path).to eq(tmp_dir)
      expect(File).to exist(tmp_dir)
    end
  end

  describe "#report_for_org" do
    it "gives us a filehandle for the org" do
      rpt = described_class.new
      expect(rpt.report_for_org("smu")).to be_a(File)
      expect(rpt.report_for_org("smu").path).to eq("#{tmp_dir}/smu_#{rpt.date_of_report}.tsv")
    end

    it "gives us a 'nonus' filehandle for non-us orgs" do
      rpt = described_class.new
      expect(rpt.report_for_org("uct").path).to eq("#{tmp_dir}/uct_#{rpt.date_of_report}_nonus.tsv")
    end
  end

  describe "#run" do
    it "has a file for each organization" do
      rpt = described_class.new
      rpt.run
      orgs.each do |org|
        expect(rpt.reports.keys).to include(org)
      end
    end

    it "only has a file for the organization given" do
      new_h = build(:holding, ocn: h2.ocn)
      Clustering::ClusterHolding.new(new_h).cluster.tap(&:save)
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

    it "has 8 columns in the report" do
      rpt = described_class.new
      rpt.run
      orgs.each do |org|
        rpt.report_for_org(org).close
        lines = File.open(rpt.report_for_org(org).path).to_a.map {|x| x.split("\t") }
        expect(lines.map(&:size)).to all(be == 8)
      end
    end

    it "has a header line" do
      rpt = described_class.new
      rpt.run
      orgs.each do |org|
        rpt.report_for_org(org).close
        header = File.open(rpt.report_for_org(org).path, &:readline).chomp
        expect(header)
          .to eq("oclc\tlocal_id\titem_type\trights\taccess\tcatalog_id\tvolume_id\tenum_chron")
      end
    end

    it "has records for holdings that don't match HTItems" do
      no_match = build(:holding, mono_multi_serial: "multi", enum_chron: "V.1")
      Clustering::ClusterHolding.new(no_match).cluster.tap(&:save)
      Clustering::ClusterHtItem.new(build(:ht_item, ocns: [no_match.ocn], enum_chron: "V.2"))
        .cluster.tap(&:save)
      rpt = described_class.new.tap(&:run)
      rpt.report_for_org(no_match.organization).close
      recs = File.readlines(rpt.report_for_org(no_match.organization).path)
      expected_rec = [no_match.ocn, no_match.local_id, no_match.mono_multi_serial,
                      "", "", "", "", ""].join("\t")
      expect(recs.find {|r| r.match?(/^#{no_match.ocn}/) }).to eq(expected_rec + "\n")
    end

    xit "runs large reports" do
      100.times do
        Clustering::ClusterHolding.new(build(:holding, ocn: h.ocn)).cluster.tap(&:save)
        Clustering::ClusterHtItem.new(build(:ht_item, ocns: [h.ocn])).cluster.tap(&:save)
      end
      rpt = described_class.new("umich")
      rpt.run
    end
  end

  describe "#convert_access" do
    it "returns whatever it was given for US orgs" do
      rpt = described_class.new
      expect(rpt.convert_access(nil, "given", "smu")).to eq("given")
    end

    it "returns 'deny' if rights is 'pdus' for non-US orgs" do
      rpt = described_class.new
      expect(rpt.convert_access("pdus", "allow", "uct")).to eq("deny")
    end

    it "returns 'allow' if rights is 'icus' for non-US orgs" do
      rpt = described_class.new
      expect(rpt.convert_access("icus", "deny", "uct")).to eq("allow")
    end

    it "returns whatever it was given if rights is not 'icus' or 'pdus' for non-US orgs" do
      rpt = described_class.new
      expect(rpt.convert_access(nil, "given", "uct")).to eq("given")
    end
  end
end
