# frozen_string_literal: true

require "spec_helper"
require "reports/cost_report"
require_relative "../../bin/reports/compile_cost_reports"

RSpec.describe "CompileCostReports" do
  # 4 HT Items
  # - 1 serial with 2 holdings one of which is from the content provider
  # - 1 spm with 0 holdings
  # - 2 mpm with the same ocns with 1 holding
  # - 1 spm with access = allow
  let(:cr) { Reports::CostReport.new(cost: 5) }

  let(:ht_serial) do
    build(:ht_item, :ser,
          collection_code: "MIU",
          access: "deny")
  end
  let(:ht_spm) do
    build(:ht_item, :spm,
          collection_code: "MIU",
          access: "deny")
  end
  let(:ht_mpm1) do
    build(:ht_item, :mpm,
          enum_chron: "1",
          n_enum: "1",
          collection_code: "MIU",
          access: "deny")
  end
  let(:ht_mpm2) do
    build(:ht_item, :mpm,
          ocns: ht_mpm1.ocns,
          ht_bib_key: ht_mpm1.ht_bib_key,
          enum_chron: "",
          collection_code: "PU",
          access: "deny")
  end
  let(:ht_spm_pd) do
    build(:ht_item, :spm,
          collection_code: "MIU",
          access: "allow")
  end
  let(:holding_serial1) { build(:holding, ocn: ht_serial.ocns.first, organization: "umich") }
  let(:holding_serial2) { build(:holding, ocn: ht_serial.ocns.first, organization: "utexas") }
  let(:serial) { build(:serial, ocns: ht_serial.ocns, record_id: ht_serial.ht_bib_key) }
  let(:holding_mpm) do
    build(:holding, ocn: ht_mpm1.ocns.first, organization: "smu", enum_chron: "", n_enum: "")
  end
  let(:texas_mpm) do
    build(:holding, ocn: ht_mpm1.ocns.first, organization: "utexas", enum_chron: "1", n_enum: "1")
  end
  let(:umich_mpm) do
    build(:holding, ocn: ht_mpm1.ocns.first, organization: "umich", enum_chron: "", n_enum: "")
  end

  before(:each) do
    Cluster.each(&:delete)
    Services.register(:ht_organzations) { mock_organizations }
    Clustering::ClusterHtItem.new(ht_serial).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht_spm).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht_mpm1).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht_mpm2).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(ht_spm_pd).cluster.tap(&:save)
    Clustering::ClusterHolding.new(holding_serial1).cluster.tap(&:save)
    Clustering::ClusterHolding.new(holding_serial2).cluster.tap(&:save)
    Clustering::ClusterHolding.new(holding_mpm).cluster.tap(&:save)
    Clustering::ClusterHolding.new(texas_mpm).cluster.tap(&:save)
    Clustering::ClusterHolding.new(umich_mpm).cluster.tap(&:save)
  end

  it "computes the correct hscores" do
    # umich has 1 instance of a spm held by 1 org (umich)
    # umich has 1 instance of a ser held by 2 org (umich and utexas)
    # umich has 2 instance of a mpm held by 3 org ([smu, umich, utexas] and [smu, umich, upenn])
    expect(cr.freq_table[:umich]).to eq(spm: { 1=>1 }, ser: { 2=>1 }, mpm: { 3=>2 })
    # 1/2 of the ht_serial
    # 1 of the ht_spm
    # 1/3 of ht_mpm1 (with SMU and upenn)
    # 1/3 of ht_mpm2 (with SMU and upenn)
    expect(cr.total_hscore(:umich)).to be_within(0.0001).of(1/2.0 + 1.0 + 1/3.0 + 1/3.0)
    # 1 instance of a ser held by 2 orgs (umich and utexas)
    # 1 instance of a mpm held by 3 orgs (smu, umich, utexas)
    expect(cr.freq_table[:utexas]).to eq(ser: { 2 => 1 }, mpm: { 3 => 1 })
  end

  it "computes total pd_cost" do
    expect(cr.pd_cost).to be_within(0.0001).of(1 * cr.target_cost / cr.num_volumes)
  end

  it "computes costs for each format" do
    # target_cost = $5
    # num_volumes = 5
    # cost_per_volume = $1
    expect(cr.spm_costs(:umich)).to eq(1.0)
    # A third of two volumes for $1 each
    expect(cr.mpm_costs(:umich)).to eq(1/3.0 * 2 * 1.00)
    expect(cr.ser_costs(:umich)).to eq(1/2.0 * 1 * 1.00)
  end

  it "computes total IC costs for a member" do
    expect(cr.total_ic_costs(:umich)).to eq(cr.total_hscore(:umich) * 1.0)
  end

  it "produces .tsv output" do
    expect(to_tsv(cr)).to eq([
      "member_id	spm	mpm	ser	pd	weight	extra	total",
      "hathitrust	0.0	0.0	0.0	0.0	0.0	0.0	0.0",
      "smu	0.0	0.6666666666666666	0.0	0.125	1.0	0.0	0.7916666666666666",
      "stanford	0.0	0.0	0.0	0.125	1.0	0.0	0.125",
      "ualberta	0.0	0.0	0.0	0.125	1.0	0.0	0.125",
      "umich	1.0	0.6666666666666666	0.5	0.125	1.0	0.0	2.2916666666666665",
      "upenn	0.0	0.3333333333333333	0.0	0.125	1.0	0.0	0.4583333333333333",
      "utexas	0.0	0.3333333333333333	0.5	0.375	3.0	0.0	1.2083333333333333"
    ].join("\n"))
  end

  it "has a setting for where to dump freq files" do
    expect(Settings.cost_report_freq_path.length).to be > 5
  end

  it "dumps frequency table upon request" do
    cr.dump_freq_table("freq.txt")
    expect(File).to exist(File.join(Settings.cost_report_freq_path, "freq.txt"))
  end
end
