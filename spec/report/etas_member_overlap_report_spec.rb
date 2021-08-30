# frozen_string_literal: true

require "spec_helper"
require "pp"
require_relative "../../bin/reports/export_etas_overlap_report"

RSpec.describe EtasMemberOverlapReport do
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
      expect(rpt.report_for_org("test")).to be_a(File)
      expect(rpt.report_for_org("test").path).to eq("#{tmp_dir}/test_#{rpt.date_of_report}.tsv")
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

    it "has a line for each ht_item in the holding member rpt" do
      rpt = described_class.new
      rpt.run
      f = rpt.report_for_org(h.organization)
      f.close
      lines = File.open(f.path).to_a
      expect(lines.size).to eq(2)
    end

    it "has 1 line with empty rights/access for the non-matching member" do
      rpt = described_class.new
      rpt.run
      f = rpt.report_for_org(h2.organization)
      f.close
      lines = File.open(rpt.report_for_org(h2.organization).path).to_a
      expect(lines.size).to eq(1)
      rec = lines.first.split("\t")
      expect(rec[3]).to eq("")
      expect(rec[4]).to eq("\n")
    end

    it "has 5 columns in the report" do
      rpt = described_class.new
      rpt.run
      orgs.each do |org|
        lines = File.open(rpt.report_for_org(org).path).to_a.map {|x| x.split("\t") }
        expect(lines.map(&:size)).to all(be == 5)
      end
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
end
