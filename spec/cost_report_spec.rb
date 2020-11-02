# frozen_string_literal: true

require "cost_report"

RSpec.describe CostReport do
  let(:cr) { described_class.new }
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
  let(:holding) { build(:holding, ocn: c.ocns.first, organization: "umich") }
  let(:holding2) { build(:holding, ocn: c.ocns.first, organization: "smu") }

  before(:each) do
    Cluster.each(&:delete)
    c.save
    c2.save
    ClusterHtItem.new(spm).cluster.tap(&:save)
    ClusterHtItem.new(mpm).cluster.tap(&:save)
    ClusterHolding.new(holding).cluster.tap(&:save)
    ClusterHolding.new(holding2).cluster.tap(&:save)
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

  describe "#add_ht_item_to_freq_table" do
    it "adds an ht_item to the freq_table for all matching orgs" do
      cr.add_ht_item_to_freq_table(mpm)
      expect(cr.freq_table).to eq(stanford: { 1 => 1 })
    end
  end

  describe "#total_hscore" do
    let(:freq) { { umich: { 1 => 5, 2 => 3, 3 => 1 }, smu: { 1 => 2, 2 => 1 } } }

    it "compiles the total hscore" do
      cr.freq_table = freq
      expect(cr.total_hscore[:umich]).to \
        be_within(0.0001).of(5.0 / 1.0 + 3.0 / 2.0 + 1.0 / 3.0)
      expect(cr.total_hscore[:smu]).to \
        be_within(0.0001).of(2.0 / 1.0 + 1.0 / 2.0)
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
        expect(cr.freq_table).to eq(spm.billing_entity.to_sym => { 1 => 2 })
      end

      it "handles multiple copies of the same spm and holdings" do
        ClusterHtItem.new(spm).cluster.tap(&:save)
        ClusterHtItem.new(ht_copy).cluster.tap(&:save)
        ClusterHolding.new(spm_holding).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each {|ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expect(cr.freq_table).to eq(spm.billing_entity.to_sym => { 1 => 2 })
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
        expect(cr.freq_table).to eq(spm.billing_entity.to_sym => { 1 => 1 })
      end

      it "HtItem derived holdings apply to all Items in the cluster" do
        ClusterHtItem.new(spm).cluster.tap(&:save)
        ht_copy.billing_entity = "different_cpc"
        ClusterHtItem.new(ht_copy).cluster.tap(&:save)
        cr.matching_clusters.each do |c|
          c.ht_items.each {|ht_item| cr.add_ht_item_to_freq_table(ht_item) }
        end
        expected_freq = { spm.billing_entity.to_sym => { 2 => 2 },
                         different_cpc: { 2 => 2 } }
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
        expect(cr.freq_table[mpm_wo_ec.organization.to_sym]).to eq(2 => 1)
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
        expect(cr.freq_table[holding_serial.organization.to_sym]).to eq(3 => 2)
      end
    end
  end
end
