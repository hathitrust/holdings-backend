# frozen_string_literal: true

require "spec_helper"
require "frequency_table"

RSpec.describe FrequencyTable do
  include_context "with tables for holdings"

  let(:ft) { described_class.new }
  let(:umich_data) { {umich: {spm: {"1": 1}}} }
  let(:upenn_data) { {upenn: {spm: {"1": 1}}} }
  let(:ft_with_data) { described_class.new(data: umich_data.merge(upenn_data)) }
  let(:frequency_1_1) { Frequency.new(bucket: 1, frequency: 1) }
  let(:frequency_1_2) { Frequency.new(bucket: 1, frequency: 2) }
  let(:frequency_2_1) { Frequency.new(bucket: 2, frequency: 1) }
  let(:frequency_2_2) { Frequency.new(bucket: 2, frequency: 2) }

  describe ".new" do
    it "creates a `FrequencyTable`" do
      expect(ft).to be_a(FrequencyTable)
    end

    it "accepts a Hash" do
      expect(described_class.new(data: {})).to be_a described_class
    end

    it "operates on a copy of the initializer data" do
      ft = described_class.new(data: umich_data)
      umich_data[:umich][:spm][:"1"] = 10
      expect(ft.frequencies(organization: :umich, format: :spm)).to eq([frequency_1_1])
    end

    it "accepts JSON" do
      expect(described_class.new(data: "{}")).to be_a described_class
    end

    it "round-trips JSON" do
      round_tripped = described_class.new(data: ft_with_data.to_json)
      expect(round_tripped).to eq(ft_with_data)
    end

    it "raises on unhandled types" do
      expect { described_class.new(data: 3.14159) }.to raise_error(RuntimeError)
    end
  end

  describe "#frequencies" do
    let(:ft1) { described_class.new(data: umich_data) }
    let(:freqs) { ft1.frequencies(organization: :umich, format: :spm) }

    it "returns an Array of Frequency" do
      expect(freqs).to be_a(Array)
      expect(freqs.first).to eq(frequency_1_1)
    end

    it "returns empty Array for unattested organization" do
      expect(ft1.frequencies(organization: :nobody_here_by_that_name, format: :spm)).to eq([])
    end

    it "returns empty Array for unattested format" do
      expect(ft1.frequencies(organization: :umich, format: :mpm)).to eq([])
    end

    it "counts OCN-less items" do
      ocnless_item = build(
        :ht_item,
        :spm,
        ocns: [],
        access: "deny",
        rights: "ic",
        billing_entity: "upenn"
      )
      load_test_data ocnless_item
      ft = described_class.new
      ft.add_ht_item(ocnless_item)
      expect(ft.frequencies(organization: :upenn, format: :spm)).to eq([frequency_1_1])
    end

    describe "Non-member holdings" do
      let(:c) { build(:cluster) }
      let(:spm) { build(:ht_item, :spm, ocns: c.ocns, access: "deny", rights: "ic", billing_entity: "upenn") }
      let(:holding) { build(:holding, ocn: c.ocns.first, organization: "umich") }
      let(:holding2) { build(:holding, ocn: c.ocns.first, organization: "upenn") }
      let(:non_member_holding) do
        Services.ht_organizations.add_temp(
          DataSources::HTOrganization.new(inst_id: "non_member", country_code: "xx",
            weight: 1.0, status: false)
        )
        build(:holding,
          ocn: spm.ocns.first,
          organization: "non_member")
      end

      it "includes only member holdings" do
        load_test_data(spm, holding, holding2, non_member_holding)
        ft = described_class.new
        ft.add_ht_item(spm)
        expect(ft.frequencies(organization: :umich, format: :spm)).to eq([frequency_2_1])
        expect(ft.frequencies(organization: :upenn, format: :spm)).to eq([frequency_2_1])
        expect(ft.keys).not_to include(:non_member)
      end
    end

    describe "spm/mpm/ser behavior" do
      let(:c) { build(:cluster) }
      let(:spm) { build(:ht_item, :spm, ocns: c.ocns, access: "deny", rights: "ic", billing_entity: "upenn") }
      let(:mpm) { build(:ht_item, :mpm, billing_entity: "ualberta", access: "deny", rights: "ic") }
      let(:ht_allow) { build(:ht_item, access: "allow", rights: "pd") }
      let(:holding) { build(:holding, ocn: c.ocns.first, organization: "umich") }
      let(:holding2) { build(:holding, ocn: c.ocns.first, organization: "upenn") }
      let(:ft) { described_class.new }

      before(:each) do
        Services.ht_organizations.add_temp(
          DataSources::HTOrganization.new(inst_id: "different_cpc", country_code: "xx", weight: 1.0)
        )
      end

      context "with multiple HTItem/Holding spms" do
        let(:ht_copy) do
          build(
            :ht_item, :spm,
            ocns: spm.ocns,
            collection_code: spm.collection_code,
            access: "deny",
            rights: "ic"
          )
        end
        let(:spm_holding) do
          build(:holding,
            enum_chron: "",
            organization: spm.billing_entity,
            ocn: spm.ocns.first)
        end

        it "handles multiple HT copies of the same spm" do
          load_test_data(spm, ht_copy)
          [spm, ht_copy].each { |item| ft.add_ht_item(item) }
          expect(ft.frequencies(organization: spm.billing_entity, format: :spm)).to eq([frequency_1_2])
        end

        it "handles multiple copies of the same spm and holdings" do
          load_test_data(spm, ht_copy, spm_holding)
          [spm, ht_copy].each { |item| ft.add_ht_item(item) }
          expect(ft.frequencies(organization: spm.billing_entity, format: :spm)).to eq([frequency_1_2])
        end

        it "multiple holdings lead to one hshare" do
          mpm_holding = spm_holding.clone
          mpm_holding.uuid = SecureRandom.uuid
          mpm_holding.n_enum = "1"
          mpm_holding.mono_multi_serial = "mpm"
          load_test_data(spm, spm_holding, mpm_holding)
          ft.add_ht_item(spm)
          expect(ft.frequencies(organization: spm.billing_entity, format: :spm)).to eq([frequency_1_1])
        end

        it "HtItem billing entity derived matches are independent of all others in the cluster" do
          # two ht items, one upenn, one michigan
          ht_copy.collection_code = "MIU"
          load_test_data(spm, ht_copy)
          [spm, ht_copy].each { |item| ft.add_ht_item(item) }
          expected_data = {upenn: {spm: {"1": 1}},
                           umich: {spm: {"1": 1}}}
          expect(ft).to eq(FrequencyTable.new(data: expected_data))
        end
      end

      context "with MPM holding without enum chron" do
        let(:mpm_wo_ec) { build(:holding, ocn: mpm.ocns.first, organization: "umich") }

        it "assigns mpm shares to empty enum chron holdings" do
          load_test_data(mpm, mpm_wo_ec)
          ft.add_ht_item(mpm)
          expect(ft.frequencies(organization: mpm_wo_ec.organization, format: :mpm)).to eq([frequency_2_1])
        end
      end

      context "with MPM holding with the wrong enum_chron" do
        let(:mpm_wrong_ec) do
          build(:holding,
            ocn: mpm.ocns.first,
            organization: "umich",
            enum_chron: "2",
            n_enum: "2")
        end

        it "gives mpm shares when enum_chron does not match anything" do
          load_test_data(mpm, mpm_wrong_ec)
          ft.add_ht_item(mpm)
          expect(ft.frequencies(organization: mpm_wrong_ec.organization, format: :mpm)).to eq([frequency_2_1])
        end
      end

      context "with Serials" do
        let(:ht_serial) do
          build(:ht_item, :ser, access: "deny", rights: "ic")
        end
        let(:ht_serial2) do
          build(
            :ht_item, :ser,
            ht_bib_key: ht_serial.ht_bib_key,
            ocns: ht_serial.ocns,
            billing_entity: "not_ht_serial.billing_entity",
            access: "deny",
            rights: "ic"
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
          load_test_data(ht_serial, ht_serial2, holding_serial)
          [ht_serial, ht_serial2].each { |item| ft.add_ht_item(item) }
          # ht_serial.billing_entity + holding_serial.org and
          # ht_serial2.billing_entity + holding_serial.org
          expect(ft.frequencies(organization: holding_serial.organization, format: :ser)).to eq([frequency_2_2])
        end
      end
    end
  end

  describe "#append!" do
    let(:ft1) { described_class.new(data: umich_data) }
    let(:ft2) { described_class.new(data: upenn_data) }

    it "returns the reciever" do
      expect(ft1.append!(ft2).object_id).to eq(ft1.object_id)
    end

    it "adds organizations" do
      expected_keys = (ft1.keys + ft2.keys).uniq.sort
      expect(ft1.append!(ft2).keys).to eq(expected_keys)
    end

    it "adds counts" do
      ft2.increment(organization: :umich, format: :spm, bucket: 1)
      expect(ft1.append!(ft2).frequencies(organization: :umich, format: :spm)).to eq([frequency_1_2])
    end

    it "adds formats" do
      ft2.increment(organization: :umich, format: :mpm, bucket: 10)
      expect(ft1.append!(ft2).frequencies(organization: :umich, format: :mpm)).to eq(
        [Frequency.new(bucket: 10, frequency: 1)]
      )
    end

    it "isolates the receiver from subsequent changes to added table" do
      ft1.append! ft2
      # Add an organization, a format, a bucket, and a count
      ft2.increment(organization: :smu, format: :spm, bucket: 1)
      ft2.increment(organization: :upenn, format: :ser, bucket: 1)
      ft2.increment(organization: :upenn, format: :spm, bucket: 10)
      ft2.increment(organization: :umich, format: :spm, bucket: 1)
      expect(ft1.keys).not_to include(:smu)
      expect(ft1.frequencies(organization: :upenn, format: :ser)).to eq([])
      expect(ft1.frequencies(organization: :upenn, format: :spm)).to eq([frequency_1_1])
    end
  end

  describe "#+" do
    let(:ft1) { described_class.new(data: umich_data) }
    let(:ft2) { described_class.new(data: upenn_data) }

    it "returns a new FrequencyTable" do
      ft3 = ft1 + ft2
      expect(ft3).to be_a(described_class)
      expect(ft3.object_id).not_to eq(ft1.object_id)
      expect(ft3.object_id).not_to eq(ft2.object_id)
    end

    it "returns a FrequencyTable with all organizations in the addends" do
      expected_keys = (ft1.keys + ft2.keys).uniq.sort
      ft3 = ft1 + ft2
      expect(ft3.keys.sort).to eq(expected_keys)
    end

    it "returns a FrequencyTable with all counts in the addends" do
      ft2.increment(organization: :umich, format: :spm, bucket: 1)
      ft3 = ft1 + ft2
      expect(ft3.frequencies(organization: :umich, format: :spm)).to eq([frequency_1_2])
      expect(ft3.frequencies(organization: :upenn, format: :spm)).to eq([frequency_1_1])
    end
  end

  describe "#add_ht_item" do
    it "adds an item" do
      ht_item = build(
        :ht_item,
        :spm,
        ocns: [5],
        access: "deny",
        rights: "ic",
        collection_code: "MIU"
      )
      insert_htitem ht_item
      ft.add_ht_item(ht_item)
      expect(ft.frequencies(organization: :umich, format: :spm)).to eq([frequency_1_1])
    end
  end

  describe "#to_json" do
    it "produces JSON String that parses to a Hash" do
      expect(ft_with_data.to_json).to be_a(String)
      expect(JSON.parse(ft_with_data.to_json)).to be_a(Hash)
    end
  end
end

RSpec.describe Frequency do
  let(:freq) { described_class.new(bucket: 1, frequency: 2) }

  describe ".new" do
    it "creates a `#{described_class}`" do
      expect(freq).to be_a(described_class)
    end

    it "accepts symbolized bucket and returns integer" do
      from_bucket_sym = described_class.new(bucket: :"1", frequency: 2)
      expect(from_bucket_sym).to be_a(described_class)
      expect(from_bucket_sym.bucket).to eq(1)
    end

    it "raises on non-Integer frequency" do
      expect { described_class.new(bucket: 1, frequency: Date.new) }.to raise_error(RuntimeError)
    end
  end

  describe "#bucket" do
    it "returns the bucket" do
      expect(freq.bucket).to eq(1)
    end
  end

  describe "#member_count" do
    it "returns the bucket under the `member_count` alias" do
      expect(freq.member_count).to eq(1)
    end
  end

  describe "#frequency" do
    it "returns the frequency" do
      expect(freq.frequency).to eq(2)
    end
  end

  describe "#to_a" do
    it "returns [bucket, frequency]" do
      expect(freq.to_a).to eq([1, 2])
    end
  end

  describe "#to_h" do
    it "returns {bucket => bucket, frequency => frequency}" do
      expect(freq.to_h).to eq({bucket: 1, frequency: 2})
    end
  end
end
