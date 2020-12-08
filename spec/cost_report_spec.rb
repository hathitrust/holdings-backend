# frozen_string_literal: true

require "spec_helper"
require "cost_report"
require "cluster_holding"
require "cluster_ht_item"

RSpec.describe CostReport do
  let(:cr) { described_class.new(cost: 10) }
  let(:c) { build(:cluster) }
  let(:c2) { build(:cluster) }
  let(:spm) do
    build(:ht_item,
          ocns: c.ocns,
            enum_chron: "",
            access: "deny",
            billing_entity: "smu")
  end
  let(:mpm) do
    build(:ht_item,
          enum_chron: "1",
            n_enum: "1",
            billing_entity: "stanford",
            access: "deny")
  end
  let(:ht_allow) { build(:ht_item, access: "allow") }
  let(:holding) { build(:holding, ocn: c.ocns.first, organization: "umich") }
  let(:holding2) { build(:holding, ocn: c.ocns.first, organization: "smu") }

  before(:each) do
    ENV["target_cost"] = "10"
    Cluster.each(&:delete)
    c.save
    c2.save
    ClusterHtItem.new(spm).cluster.tap(&:save)
    ClusterHtItem.new(mpm).cluster.tap(&:save)
    ClusterHolding.new(holding).cluster.tap(&:save)
    ClusterHolding.new(holding2).cluster.tap(&:save)
  end

  describe "#num_volumes" do
    it "counts the number of volumes" do
      expect(cr.num_volumes).to eq(2)
    end
  end

  describe "#num_pd_volumes" do
    it "counts the number of pd volumes" do
      ClusterHtItem.new(ht_allow).cluster.tap(&:save)
      ClusterHtItem.new(build(:ht_item, access: "allow", ocns: ht_allow.ocns)).cluster.tap(&:save)
      expect(cr.num_pd_volumes).to eq(2)
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
      pd_item = build(:ht_item,
                      access: "allow",
                      enum_chron: "1",
                      n_enum: "1",
                      billing_entity: "upenn")
      ClusterHtItem.new(pd_item).cluster.tap(&:save)
      expect(cr.freq_table[:upenn][:mpm]).to eq({})
    end
  end

  describe "#add_ht_item_to_freq_table" do
    it "adds an ht_item to the freq_table for all matching orgs" do
      cr.add_ht_item_to_freq_table(mpm)
      expect(cr.freq_table).to eq(stanford: { mpm: { 1 => 1 } })
    end
  end

  describe "#matching_clusters" do
    it "finds all clusters with an HTItem" do
      expect(described_class.new.matching_clusters.each.to_a.size).to eq(2)
    end

    it "finds clusters with a matching HTItem : holding" do
      expect(described_class.new("umich").matching_clusters.each.to_a.size).to eq(1)
    end

    it "finds a cluster if it only has an HTItem" do
      expect(described_class.new("stanford").matching_clusters.each.to_a.size).to eq(1)
    end

    it "does not find clusters with only access == allow" do
      ClusterHtItem.new(build(:ht_item, access: "allow")).cluster.tap(&:save)
      expect(described_class.new.matching_clusters.each.to_a.size).to eq(2)
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
          be_within(0.0001).of((5.0 / 1 + 3.0 /2.0) * cr.cost_per_volume)
      end

      it "computes the total cost for a given member for a mpm format" do
        expect(cr.mpm_costs(:umich)).to \
          be_within(0.0001).of((1 / 3.0) * cr.cost_per_volume)
      end

      it "computes the total cost for a given member for a ser format" do
        expect(cr.ser_costs(:smu)).to \
          be_within(0.0001).of((2.0 / 1 + 1.0 /2.0) * cr.cost_per_volume)
      end
    end

    describe "#extra_per_member" do
      it "computes the extra costs allotted to members" do
        # we have no IC items that don't have a billing entity
        expect(cr.extra_per_member).to be_within(0.0001).of(0)
        cr.freq_table[:hathitrust][:spm][1] =1
        expect(cr.extra_per_member).to be_within(0.0001).of(cr.cost_per_volume / 6)
      end
    end
  end

  describe "Integration testing of spm/mpm/serial behavior" do
    let(:cr) { described_class.new }

    before(:each) do
      Cluster.each(&:delete)
    end

    describe "multiple HTItem/Holding spms" do
      let(:ht_copy) do
        build(:ht_item,
              enum_chron: "",
              ocns: spm.ocns,
              billing_entity: spm.billing_entity,
              access: "deny")
      end
      let(:spm_holding) do
        build(:holding,
              enum_chron: "",
              organization: spm.billing_entity,
              ocn: spm.ocns.first)
      end

      it "handles multiple HT copies of the same spm" do
        ClusterHtItem.new(spm).cluster.tap(&:save)
        ClusterHtItem.new(ht_copy).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each {|ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expect(cr.freq_table).to eq(spm.billing_entity.to_sym => { spm: { 1 => 2 } })
      end

      it "handles multiple copies of the same spm and holdings" do
        ClusterHtItem.new(spm).cluster.tap(&:save)
        ClusterHtItem.new(ht_copy).cluster.tap(&:save)
        ClusterHolding.new(spm_holding).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each {|ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expect(cr.freq_table).to eq(spm.billing_entity.to_sym => { spm: { 1 => 2 } })
      end

      it "multiple holdings lead to one hshare" do
        ClusterHtItem.new(spm).cluster.tap(&:save)
        mpm_holding = spm_holding.clone
        mpm_holding.n_enum = "1"
        mpm_holding.mono_multi_serial = "multi"
        ClusterHolding.new(spm_holding).cluster.tap(&:save)
        ClusterHolding.new(mpm_holding).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each {|ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expect(cr.freq_table).to eq(spm.billing_entity.to_sym => { spm: { 1 => 1 } })
      end

      it "HtItem derived holdings apply to all Items in the cluster" do
        ClusterHtItem.new(spm).cluster.tap(&:save)
        ht_copy.billing_entity = "different_cpc"
        ClusterHtItem.new(ht_copy).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each {|ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expected_freq = { spm.billing_entity.to_sym => { spm: { 2 => 2 } },
                         different_cpc: { spm: { 2 => 2 } } }
        expect(cr.freq_table).to eq(expected_freq)
      end
    end

    describe "MPM holding without enum chron" do
      let(:mpm_wo_ec) { build(:holding, ocn: mpm.ocns.first, organization: "umich") }

      it "assigns mpm shares to empty enum chron holdings" do
        ClusterHtItem.new(mpm).cluster.tap(&:save)
        ClusterHolding.new(mpm_wo_ec).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each {|ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expect(cr.freq_table[mpm_wo_ec.organization.to_sym]).to eq(mpm: { 2 => 1 })
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

      it "does not give mpm shares when enum_chron does not match" do
        ClusterHtItem.new(mpm).cluster.tap(&:save)
        ClusterHolding.new(mpm_wrong_ec).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each {|ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expect(cr.freq_table[mpm_wrong_ec.organization.to_sym]).to eq({})
      end
    end

    describe "Serials" do
      let(:ht_serial) do
        build(:ht_item,
              enum_chron: "1",
              n_enum: "1",
              bib_fmt: "s",
              access: "deny")
      end
      let(:ht_serial2) do
        build(:ht_item,
              ht_bib_key: ht_serial.ht_bib_key,
              ocns: ht_serial.ocns,
              enum_chron: "2",
              n_enum: "2",
              bib_fmt: "s",
              billing_entity: "not_ht_serial.billing_entity",
              access: "deny")
      end
      let(:serial) { build(:serial, ocns: ht_serial.ocns, record_id: ht_serial.ht_bib_key) }
      let(:holding_serial) do
        Services.ht_members.add_temp(
          HTMember.new(inst_id: "not_a_collection", country_code: "xx", weight: 1.0)
        )

        build(:holding,
              ocn: ht_serial.ocns.first,
              enum_chron: "3",
              n_enum: "3",
              organization: "not_a_collection")
      end

      it "assigns all serials to the member and ht_item derived holdings affect hshare" do
        ClusterHtItem.new(ht_serial).cluster.tap(&:save)
        ClusterHtItem.new(ht_serial2).cluster.tap(&:save)
        Services.serials.bibkeys.add(ht_serial.ht_bib_key.to_i)
        ClusterHolding.new(holding_serial).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each {|ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        # ht_serial.billing_entity + ht_serial2.billing_entity + holding_serial.org
        expect(cr.freq_table[holding_serial.organization.to_sym]).to eq(ser: { 3 => 2 })
      end
    end
  end
end
