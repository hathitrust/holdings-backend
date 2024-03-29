# frozen_string_literal: true

require "spec_helper"
require "reports/cost_report"
require "clustering/cluster_holding"
require "clustering/cluster_ht_item"
require "data_sources/ht_organizations"

RSpec.describe Reports::CostReport do
  let(:alo) { "allow" }
  let(:dni) { "deny" }
  let(:pd) { "pd" }
  let(:ic) { "ic" }
  let(:icus) { "icus" }

  let(:cr) { described_class.new(cost: 10) }
  let(:c) { build(:cluster) }
  let(:c2) { build(:cluster) }
  let(:spm) { build(:ht_item, :spm, ocns: c.ocns, access: dni, rights: ic, billing_entity: "smu") }
  let(:mpm) { build(:ht_item, :mpm, billing_entity: "stanford", access: dni, rights: ic) }
  let(:ht_allow) { build(:ht_item, access: alo, rights: pd) }
  let(:holding) { build(:holding, ocn: c.ocns.first, organization: "umich") }
  let(:holding2) { build(:holding, ocn: c.ocns.first, organization: "smu") }

  before(:each) do
    Cluster.each(&:delete)
    c.save
    c2.save
    Clustering::ClusterHtItem.new(spm).cluster.tap(&:save)
    Clustering::ClusterHtItem.new(mpm).cluster.tap(&:save)
    Clustering::ClusterHolding.new(holding).cluster.tap(&:save)
    Clustering::ClusterHolding.new(holding2).cluster.tap(&:save)
  end

  describe "#num_volumes" do
    it "counts the number of volumes" do
      expect(cr.num_volumes).to eq(2)
    end
  end

  describe "making sure that access and rights come out the way they go in" do
    it "pd == allow" do
      cluster_tap_save build(:ht_item, access: alo, rights: pd, ocns: [111])
      cluster = Cluster.find_by(ocns: 111)
      expect(cluster.ht_items.count).to eq 1
      expect(cluster.ht_items.first.rights).to eq pd
      expect(cluster.ht_items.first.access).to eq alo
    end
    it "icus == allow" do
      cluster_tap_save build(:ht_item, access: alo, rights: icus, ocns: [222])
      cluster = Cluster.find_by(ocns: 222)
      expect(cluster.ht_items.count).to eq 1
      expect(cluster.ht_items.first.rights).to eq icus
      expect(cluster.ht_items.first.access).to eq alo
    end
    it "ic == deny" do
      cluster_tap_save build(:ht_item, access: dni, rights: ic, ocns: [333])
      cluster = Cluster.find_by(ocns: 333)
      expect(cluster.ht_items.count).to eq 1
      expect(cluster.ht_items.first.rights).to eq ic
      expect(cluster.ht_items.first.access).to eq dni
    end
  end

  describe "#num_pd_volumes" do
    it "counts the number of pd volumes" do
      cluster_tap_save ht_allow, build(:ht_item, access: alo, rights: pd, ocns: ht_allow.ocns)
      expect(cr.num_pd_volumes).to eq(2)
    end
    it "counts icus towards pd regardless of access" do
      # Put 10 icus items in...
      1.upto(10) do
        cluster_tap_save build(:ht_item, rights: icus)
      end
      # Expect all 10 when you call num_pd_volumes
      expect(cr.num_pd_volumes).to eq(10)
      # Expect none when you call ic_volumes
      expect(cr.ic_volumes.count { |v| v.rights == icus }).to eq(0)
    end
  end

  describe "#cost_per_volume" do
    it "calculates cost per volume" do
      expect(cr.cost_per_volume).to eq(cr.target_cost / cr.num_volumes)
    end
  end

  describe "#total_weight" do
    it "compiles the total weights of all members" do
      # mock_members
      expect(cr.total_weight).to eq(8.0)
    end
  end

  describe "#pd_cost" do
    it "calculates base pd cost" do
      expect(cr.pd_cost).to eq(cr.num_pd_volumes * cr.cost_per_volume)
    end
  end

  describe "#pd_cost_for_member" do
    it "calculates pd cost for a member weight" do
      # mock_members umich and utexas have weights 1 and 3 respectively
      expect(cr.pd_cost_for_member(:umich)).to eq(cr.pd_cost / 8.0 * 1.0)
      expect(cr.pd_cost_for_member(:utexas)).to eq(cr.pd_cost / 8.0 * 3.0)
    end
  end

  describe "#compile_frequency_table" do
    it "ignores PD items" do
      pd_item = build(
        :ht_item,
        access: alo,
        rights: pd,
        enum_chron: "1",
        n_enum: "1",
        billing_entity: "upenn"
      )
      Clustering::ClusterHtItem.new(pd_item).cluster.tap(&:save)
      expect(cr.freq_table[:upenn][:mpm]).to eq({})
    end
  end

  describe "#add_ht_item_to_freq_table" do
    it "adds an ht_item to the freq_table for all matching orgs" do
      cr.add_ht_item_to_freq_table(mpm)
      expect(cr.freq_table).to eq(stanford: {mpm: {1 => 1}})
    end
  end

  describe "#matching_clusters" do
    it "finds all clusters with an HTItem" do
      expect(described_class.new.matching_clusters.each.to_a.size).to eq(2)
    end

    it "finds clusters with a matching HTItem : holding" do
      expect(described_class.new(organization: "umich").matching_clusters.each.to_a.size).to eq(1)
    end

    it "finds a cluster if it only has an HTItem" do
      expect(described_class.new(organization: "stanford").matching_clusters.each.to_a.size).to eq(1)
    end

    it "does not find clusters with only access == allow" do
      Clustering::ClusterHtItem.new(build(:ht_item, access: alo, rights: pd)).cluster.tap(&:save)
      expect(described_class.new.matching_clusters.each.to_a.size).to eq(2)
    end
  end

  describe "Non-member holdings" do
    let(:non_member_holding) do
      Services.ht_organizations.add_temp(
        DataSources::HTOrganization.new(inst_id: "non_member", country_code: "xx",
          weight: 1.0, status: false)
      )
      build(:holding,
        ocn: Cluster.first.ocns.first,
        organization: "non_member")
    end

    it "does not include non-member holdings" do
      Clustering::ClusterHolding.new(non_member_holding).cluster.tap(&:save)
      cr.matching_clusters.each do |c|
        c.ht_items.each { |ht_item| cr.add_ht_item_to_freq_table(ht_item) }
      end
      expect(cr.freq_table[:umich][:spm]).to eq({2 => 1})
      expect(cr.freq_table[:non_member]).to eq({})
    end
  end

  describe "HScores and Costs" do
    before(:each) do
      Cluster.each(&:delete)
      cr.freq_table[:umich][:spm][1] = 5
      cr.freq_table[:umich][:spm][2] = 3
      cr.freq_table[:umich][:mpm][3] = 1
      cr.freq_table[:smu][:ser][1] = 2
      cr.freq_table[:smu][:ser][2] = 1
      cr.instance_variable_set(:@num_volumes, 12)
    end

    describe "#total_hscore" do
      it "compiles the total hscore" do
        expect(cr.total_hscore(:umich)).to \
          be_within(0.0001).of(5.0 / 1.0 + 3.0 / 2.0 + 1.0 / 3.0)
        expect(cr.total_hscore(:smu)).to \
          be_within(0.0001).of(2.0 / 1.0 + 1.0 / 2.0)
      end
    end

    describe "#spm/ser/mpm_total" do
      it "computes the total hscore for a given member for a spm format" do
        expect(cr.spm_total(:umich)).to be_within(0.0001).of(5.0 / 1 + 3.0 / 2.0)
      end

      it "computes the total hscore for a given member for a mpm format" do
        expect(cr.mpm_total(:umich)).to be_within(0.0001).of(1.0 / 3.0)
      end

      it "computes the total hscore for a given member for a ser format" do
        expect(cr.ser_total(:smu)).to be_within(0.0001).of(2.0 / 1.0 + 1.0 / 2.0)
      end
    end

    describe "#spm/ser/mpm_costs" do
      it "computes the total cost for a given member for a spm format" do
        expect(cr.spm_costs(:umich)).to \
          be_within(0.0001).of((5.0 / 1 + 3.0 / 2.0) * cr.cost_per_volume)
      end

      it "computes the total cost for a given member for a mpm format" do
        expect(cr.mpm_costs(:umich)).to \
          be_within(0.0001).of((1 / 3.0) * cr.cost_per_volume)
      end

      it "computes the total cost for a given member for a ser format" do
        expect(cr.ser_costs(:smu)).to \
          be_within(0.0001).of((2.0 / 1 + 1.0 / 2.0) * cr.cost_per_volume)
      end
    end

    describe "#extra_per_member" do
      it "computes the extra costs allotted to members" do
        # we have no IC items that don't have a billing entity
        expect(cr.extra_per_member).to be_within(0.0001).of(0)
        cr.freq_table[:hathitrust][:spm][1] = 1
        expect(cr.extra_per_member).to be_within(0.0001).of(cr.cost_per_volume / 6)
      end
    end
  end

  describe "Integration testing of spm/mpm/ser behavior" do
    let(:cr) { described_class.new }

    before(:each) do
      Cluster.each(&:delete)
      Services.ht_organizations.add_temp(
        DataSources::HTOrganization.new(inst_id: "different_cpc", country_code: "xx", weight: 1.0)
      )
    end

    describe "multiple HTItem/Holding spms" do
      let(:ht_copy) do
        build(
          :ht_item, :spm,
          ocns: spm.ocns,
          billing_entity: spm.billing_entity,
          access: dni,
          rights: ic
        )
      end
      let(:spm_holding) do
        build(:holding,
          enum_chron: "",
          organization: spm.billing_entity,
          ocn: spm.ocns.first)
      end

      it "handles multiple HT copies of the same spm" do
        Clustering::ClusterHtItem.new(spm).cluster.tap(&:save)
        Clustering::ClusterHtItem.new(ht_copy).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each { |ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expect(cr.freq_table).to eq(spm.billing_entity.to_sym => {spm: {1 => 2}})
      end

      it "handles multiple copies of the same spm and holdings" do
        Clustering::ClusterHtItem.new(spm).cluster.tap(&:save)
        Clustering::ClusterHtItem.new(ht_copy).cluster.tap(&:save)
        Clustering::ClusterHolding.new(spm_holding).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each { |ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expect(cr.freq_table).to eq(spm.billing_entity.to_sym => {spm: {1 => 2}})
      end

      it "multiple holdings lead to one hshare" do
        Clustering::ClusterHtItem.new(spm).cluster.tap(&:save)
        mpm_holding = spm_holding.clone
        mpm_holding.n_enum = "1"
        mpm_holding.mono_multi_serial = "mpm"
        cluster = Clustering::ClusterHolding.new(spm_holding).cluster.tap(&:save)
        cluster.add_holdings(mpm_holding).tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each { |ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expect(cr.freq_table).to eq(spm.billing_entity.to_sym => {spm: {1 => 1}})
      end

      it "HtItem billing entity derived matches are independent of all others in the cluster" do
        Clustering::ClusterHtItem.new(spm).cluster.tap(&:save)
        ht_copy.billing_entity = "different_cpc"
        Clustering::ClusterHtItem.new(ht_copy).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each { |ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expected_freq = {spm.billing_entity.to_sym => {spm: {1 => 1}},
                         :different_cpc => {spm: {1 => 1}}}
        expect(cr.freq_table).to eq(expected_freq)
      end
    end

    describe "MPM holding without enum chron" do
      let(:mpm_wo_ec) { build(:holding, ocn: mpm.ocns.first, organization: "umich") }

      it "assigns mpm shares to empty enum chron holdings" do
        Clustering::ClusterHtItem.new(mpm).cluster.tap(&:save)
        Clustering::ClusterHolding.new(mpm_wo_ec).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each { |ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expect(cr.freq_table[mpm_wo_ec.organization.to_sym]).to eq(mpm: {2 => 1})
      end
    end

    describe "MPM holding with the wrong enum_chron" do
      let(:mpm_wrong_ec) do
        build(:holding,
          ocn: mpm.ocns.first,
          organization: "umich",
          enum_chron: "2",
          n_enum: "2")
      end

      it "gives mpm shares when enum_chron does not match anything" do
        Clustering::ClusterHtItem.new(mpm).cluster.tap(&:save)
        Clustering::ClusterHolding.new(mpm_wrong_ec).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each { |ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expect(cr.freq_table[mpm_wrong_ec.organization.to_sym]).to eq(mpm: {2 => 1})
      end
    end

    describe "Serials" do
      let(:ht_serial) do
        build(:ht_item, :ser, access: dni, rights: ic)
      end
      let(:ht_serial2) do
        build(
          :ht_item, :ser,
          ht_bib_key: ht_serial.ht_bib_key,
          ocns: ht_serial.ocns,
          billing_entity: "not_ht_serial.billing_entity",
          access: dni,
          rights: ic
        )
      end
      let(:holding_serial) do
        build(:holding,
          ocn: ht_serial.ocns.first,
          enum_chron: "3",
          n_enum: "3",
          organization: "not_a_collection")
      end

      before(:each) do
        Services.ht_organizations.add_temp(
          DataSources::HTOrganization.new(inst_id: "not_ht_serial.billing_entity",
            country_code: "xx", weight: 1.0, status: 1)
        )
        Services.ht_organizations.add_temp(
          DataSources::HTOrganization.new(inst_id: "not_a_collection", country_code: "xx",
            weight: 1.0, status: 1)
        )
      end

      it "assigns all serials to the member and ht_item billing entities affect hshare" do
        Clustering::ClusterHtItem.new(ht_serial).cluster.tap(&:save)
        Clustering::ClusterHtItem.new(ht_serial2).cluster.tap(&:save)
        Clustering::ClusterHolding.new(holding_serial).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each { |ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        # ht_serial.billing_entity + holding_serial.org and
        # ht_serial2.billing_entity + holding_serial.org
        expect(cr.freq_table[holding_serial.organization.to_sym]).to eq(ser: {2 => 2})
      end
    end
  end
end

RSpec.describe Reports::CostReport do
  describe "putting it all together" do
    # 4 HT Items
    # - 1 serial with 2 holdings one of which is from the content provider
    # - 1 spm with 0 holdings
    # - 2 mpm with the same ocns with 1 holding
    # - 1 spm with access = allow
    let(:cr) { Reports::CostReport.new(cost: 5) }
    let(:alo) { "allow" }
    let(:dni) { "deny" }
    let(:pd) { "pd" }
    let(:ic) { "ic" }
    let(:icus) { "icus" }

    let(:ht_serial) do
      build(
        :ht_item, :ser,
        collection_code: "MIU",
        access: dni,
        rights: ic
      )
    end
    let(:ht_spm) do
      build(
        :ht_item, :spm,
        collection_code: "MIU",
        access: dni,
        rights: ic
      )
    end
    let(:ht_mpm1) do
      build(
        :ht_item, :mpm,
        enum_chron: "1",
        n_enum: "1",
        collection_code: "MIU",
        access: dni,
        rights: ic
      )
    end
    let(:ht_mpm2) do
      build(
        :ht_item, :mpm,
        ocns: ht_mpm1.ocns,
        ht_bib_key: ht_mpm1.ht_bib_key,
        enum_chron: "",
        collection_code: "PU",
        access: dni,
        rights: ic
      )
    end
    let(:ht_spm_pd) do
      build(
        :ht_item, :spm,
        collection_code: "MIU",
        access: alo,
        rights: pd
      )
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
      expect(cr.freq_table[:umich]).to eq(spm: {1 => 1}, ser: {2 => 1}, mpm: {3 => 2})
      # 1/2 of the ht_serial
      # 1 of the ht_spm
      # 1/3 of ht_mpm1 (with SMU and upenn)
      # 1/3 of ht_mpm2 (with SMU and upenn)
      expect(cr.total_hscore(:umich)).to be_within(0.0001).of(1 / 2.0 + 1.0 + 1 / 3.0 + 1 / 3.0)
      # 1 instance of a ser held by 2 orgs (umich and utexas)
      # 1 instance of a mpm held by 3 orgs (smu, umich, utexas)
      expect(cr.freq_table[:utexas]).to eq(ser: {2 => 1}, mpm: {3 => 1})
    end

    it "produces .tsv output" do
      expect(cr.to_tsv).to eq([
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
end
