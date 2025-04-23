# frozen_string_literal: true

require "spec_helper"
require "reports/cost_report"
require "data_sources/ht_organizations"
require "frequency_table"

RSpec.describe Reports::CostReport do
  include_context "with tables for holdings"

  let(:allow) { "allow" }
  let(:deny) { "deny" }
  let(:pd) { "pd" }
  let(:ic) { "ic" }
  let(:icus) { "icus" }

  let(:cr) { described_class.new(target_cost: 10) }
  let(:c) { build(:cluster) }
  let(:spm) { build(:ht_item, :spm, ocns: c.ocns, access: deny, rights: ic, collection_code: "PU") }
  let(:mpm) { build(:ht_item, :mpm, collection_code: "AEU", access: deny, rights: ic) }
  let(:ht_allow) { build(:ht_item, access: allow, rights: pd) }
  let(:holding) { build(:holding, ocn: c.ocns.first, organization: "umich") }
  let(:holding2) { build(:holding, ocn: c.ocns.first, organization: "upenn") }
  let(:frequency_1_1) { Frequency.new(bucket: 1, frequency: 1) }
  let(:frequency_1_2) { Frequency.new(bucket: 1, frequency: 2) }
  let(:frequency_2_1) { Frequency.new(bucket: 2, frequency: 1) }
  let(:frequency_2_2) { Frequency.new(bucket: 2, frequency: 2) }
  let(:frequency_3_1) { Frequency.new(bucket: 3, frequency: 1) }
  let(:frequency_3_2) { Frequency.new(bucket: 3, frequency: 2) }

  describe "making sure that access and rights come out the way they go in" do
    it "pd == allow" do
      load_test_data(build(:ht_item, access: allow, rights: pd, ocns: [111]))
      cluster = Cluster.for_ocns([111])
      expect(cluster.ht_items.count).to eq 1
      expect(cluster.ht_items.first.rights).to eq pd
      expect(cluster.ht_items.first.access).to eq allow
    end
    it "icus == allow" do
      load_test_data(build(:ht_item, access: allow, rights: icus, ocns: [222]))
      cluster = Cluster.for_ocns([222])
      expect(cluster.ht_items.count).to eq 1
      expect(cluster.ht_items.first.rights).to eq icus
      expect(cluster.ht_items.first.access).to eq allow
    end
    it "ic == deny" do
      load_test_data(build(:ht_item, access: deny, rights: ic, ocns: [333]))
      cluster = Cluster.for_ocns([333])
      expect(cluster.ht_items.count).to eq 1
      expect(cluster.ht_items.first.rights).to eq ic
      expect(cluster.ht_items.first.access).to eq deny
    end
  end

  describe "#cost_per_volume" do
    it "calculates cost per volume" do
      # 3 volumes, target cost $10
      load_test_data(spm, mpm, ht_allow)
      expect(cr.cost_per_volume).to be_within(0.01).of(3.33)
    end
  end

  describe "#total_weight" do
    it "compiles the total weights of all members" do
      # sum of weights from spec/fixtures/organizations.rb
      expect(cr.total_weight).to eq(8.0)
    end
  end

  describe "#pd_cost" do
    it "calculates base pd cost" do
      # 3 volumes, 1 public domain, target cost $10
      load_test_data(spm, mpm, ht_allow)
      expect(cr.pd_cost).to be_within(0.01).of(3.33)
    end
  end

  describe "#pd_cost_for_member" do
    it "calculates pd cost for a member weight" do
      # 3 volumes, 1 public domain, target cost $10
      #
      # see weights from spec/fixtures/organizations.rb
      # mock_members umich and utexas have weights 1 and 3 respectively
      load_test_data(spm, mpm, ht_allow)

      # 1 pd volume, 3 total volumes, target cost $10, total weight 8
      # pd cost is 3.33, pd cost per weight is ~0.42
      #
      expect(cr.pd_cost_for_member(:umich)).to be_within(0.01).of(0.42)

      # 1 pd volume, 3 total volumes, target cost $10, total weight 8
      # pd cost is 3.33, pd cost per weight is ~0.42
      expect(cr.pd_cost_for_member(:utexas)).to be_within(0.01).of(1.25)
    end
  end

  describe "#frequency_table" do
    it "an empty frequency table can be passed to a CostReport" do
      ft = FrequencyTable.new
      cr = described_class.new(precomputed_frequency_table: ft)
      # expect hash in == hash out
      expect(cr.frequency_table).to eq ft
    end

    it "a populated frequency table can be passed to CostReport" do
      ft = FrequencyTable.new
      load_test_data(spm)
      ft.add_ht_item(spm)
      cr = described_class.new(precomputed_frequency_table: ft)
      # expect hash in == hash out
      expect(cr.frequency_table).to eq ft
    end

    it "the precomputed frequency table is used to run the cost report" do
      ft = FrequencyTable.new
      load_test_data(spm)
      ft.add_ht_item(spm)
      cr = described_class.new(precomputed_frequency_table: ft)
      cr.run

      # only one item loaded from upenn -- upenn pays for everything
      expect(cr.total_cost_for_member("upenn")).to eq Settings.target_cost
    end

    it "can use a frequency table file" do
      cr = described_class.new(frequency_table: fixture("freqtable.json"))

      expect(cr.frequency_table).to eq(FrequencyTable.new(data: {umich: {spm: {"1": 1}}}))
    end

    it "can sum a directory of frequency table files" do
      cr = described_class.new(working_directory: fixture("freqtables"))
      expect(cr.frequency_table).to eq(FrequencyTable.new(data: File.read(fixture("summed_freqtable.json"))))
    end
  end

  describe "#dump_frequency_table" do
    it "dumps frequency table" do
      load_test_data(spm, mpm, ht_allow)
      cr.dump_frequency_table("freq.txt")
      expect(File).to exist(File.join(Settings.cost_report_freq_path, "freq.txt"))
    end
  end

  describe "HScores and Costs" do
    let(:json) {
      <<~JSON
        {
          "umich":{
            "mpm":{"3":1},
            "spm":{"1":5,"2":3}
          },
          "smu":{
            "ser":{"1":2,"2":1}
          }
        }
      JSON
    }
    let(:pft) { FrequencyTable.new(data: json) }
    let(:cr) { described_class.new(target_cost: 10, precomputed_frequency_table: pft) }
    before(:each) do
      # add 3 items & 2 holdings
      load_test_data(spm, mpm, ht_allow, holding, holding2)
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
        cr.frequency_table.increment(organization: :hathitrust, format: :spm, bucket: :"1")
        expect(cr.extra_per_member).to be_within(0.0001).of(cr.cost_per_volume / 6)
      end
    end
  end

  describe "putting it all together" do
    # 4 HT Items
    # - 1 serial with 2 holdings one of which is from the content provider
    # - 1 spm with 0 holdings
    # - 2 mpm with the same ocns with 1 holding
    # - 1 spm with access = allow
    let(:ft) { FrequencyTable.new }
    let(:cr) { Reports::CostReport.new(target_cost: 5, precomputed_frequency_table: ft) }
    let(:allow) { "allow" }
    let(:deny) { "deny" }
    let(:pd) { "pd" }
    let(:ic) { "ic" }
    let(:icus) { "icus" }

    let(:ht_serial) do
      build(
        :ht_item, :ser,
        collection_code: "MIU",
        access: deny,
        rights: ic
      )
    end
    let(:ht_spm) do
      build(
        :ht_item, :spm,
        collection_code: "MIU",
        access: deny,
        rights: ic
      )
    end
    let(:ht_mpm1) do
      build(
        :ht_item, :mpm,
        enum_chron: "1",
        n_enum: "1",
        collection_code: "MIU",
        access: deny,
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
        access: deny,
        rights: ic
      )
    end
    let(:ht_spm_pd) do
      build(
        :ht_item, :spm,
        collection_code: "MIU",
        access: allow,
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
      Services.register(:ht_organzations) { mock_organizations }
      load_test_data(ht_serial, ht_spm, ht_mpm1, ht_mpm2, ht_spm_pd,
        holding_serial1, holding_serial2,
        holding_mpm, texas_mpm, umich_mpm)

      [ht_serial, ht_spm, ht_mpm1, ht_mpm2].each { |item| ft.add_ht_item(item) }
    end

    it "computes the correct hscores" do
      # umich has 1 instance of a spm held by 1 org (umich)
      # umich has 1 instance of a ser held by 2 org (umich and utexas)
      # umich has 2 instance of a mpm held by 3 org ([smu, umich, utexas] and [smu, umich, upenn])
      expect(cr.frequency_table.frequencies(organization: :umich, format: :spm)).to eq([frequency_1_1])
      expect(cr.frequency_table.frequencies(organization: :umich, format: :ser)).to eq([frequency_2_1])
      expect(cr.frequency_table.frequencies(organization: :umich, format: :mpm)).to eq([frequency_3_2])
      # 1/2 of the ht_serial
      # 1 of the ht_spm
      # 1/3 of ht_mpm1 (with SMU and upenn)
      # 1/3 of ht_mpm2 (with SMU and upenn)
      expect(cr.total_hscore(:umich)).to be_within(0.0001).of(1 / 2.0 + 1.0 + 1 / 3.0 + 1 / 3.0)
      # 1 instance of a ser held by 2 orgs (umich and utexas)
      # 1 instance of a mpm held by 3 orgs (smu, umich, utexas)
      expect(cr.frequency_table.frequencies(organization: :utexas, format: :ser)).to eq([frequency_2_1])
      expect(cr.frequency_table.frequencies(organization: :utexas, format: :mpm)).to eq([frequency_3_1])
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
  end
end
