# frozen_string_literal: true

require "spec_helper"
require "frequency_table"

RSpec.describe FrequencyTable do
  include_context "with tables for holdings"

  let(:ft) { described_class.new }
  let(:umich_data) { {umich: {spm: {"1": 1}}} }
  let(:upenn_data) { {upenn: {spm: {"1": 1}}} }
  let(:ft_data) { umich_data.merge upenn_data }
  let(:ft_with_data) { described_class.new(data: ft_data) }

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
      expect(ft.fetch(organization: :umich, format: :spm, bucket: 1)).to eq(1)
    end

    it "accepts JSON" do
      expect(described_class.new(data: "{}")).to be_a described_class
    end

    it "round-trips JSON" do
      round_tripped = described_class.new(data: ft_with_data.to_json)
      expect(round_tripped.organizations.sort).to eq [:umich, :upenn].sort
      expect(round_tripped.fetch(organization: :umich)).to eq(ft_with_data.fetch(organization: :umich))
      expect(round_tripped.fetch(organization: :upenn)).to eq(ft_with_data.fetch(organization: :upenn))
    end

    it "raises on unhandled types" do
      expect { described_class.new(data: 3.14159) }.to raise_error(RuntimeError)
    end
  end

  describe "#organizations" do
    it "returns empty Array when initialized" do
      expect(ft.organizations).to eq([])
    end

    it "returns each org in the cluster" do
      expect(ft_with_data.organizations).to eq([:umich, :upenn])
    end
  end

  describe "#append!" do
    let(:ft1) { described_class.new(data: umich_data) }
    let(:ft2) { described_class.new(data: upenn_data) }

    it "returns the reciever" do
      expect(ft1.append!(ft2).object_id).to eq(ft1.object_id)
    end

    it "adds organizations" do
      expected_keys = (ft1.organizations + ft2.organizations).uniq.sort
      expect(ft1.append!(ft2).organizations).to eq(expected_keys)
    end

    it "adds counts" do
      ft2.increment(organization: :umich, format: :spm, bucket: 1)
      expect(ft1.append!(ft2).fetch(organization: :umich, format: :spm, bucket: 1)).to eq(2)
    end

    it "adds formats" do
      ft2.increment(organization: :umich, format: :mpm, bucket: 10)
      expect(ft1.append!(ft2).fetch(organization: :umich, format: :mpm, bucket: 10)).to eq(1)
    end

    it "isolates the receiver from subsequent changes to added table" do
      ft1.append! ft2
      # Add an organization, a format, a bucket, and a count
      ft2.increment(organization: :smu, format: :spm, bucket: 1)
      ft2.increment(organization: :upenn, format: :ser, bucket: 1)
      ft2.increment(organization: :upenn, format: :spm, bucket: 10)
      ft2.increment(organization: :umich, format: :spm, bucket: 1)
      expect(ft1.organizations).not_to include(:smu)
      expect(ft1.fetch(organization: :upenn, format: :ser)).to eq({})
      expect(ft1.fetch(organization: :upenn, format: :spm, bucket: 10)).to eq(0)
      expect(ft1.fetch(organization: :upenn, format: :spm, bucket: 1)).to eq(1)
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
      expected_keys = (ft1.organizations + ft2.organizations).uniq.sort
      ft3 = ft1 + ft2
      expect(ft3.organizations).to eq(expected_keys)
    end

    it "returns a FrequencyTable with all counts in the addends" do
      ft2.increment(organization: :umich, format: :spm, bucket: 1)
      ft3 = ft1 + ft2
      expect(ft3.fetch(organization: :umich, format: :spm, bucket: 1)).to eq(2)
      expect(ft3.fetch(organization: :upenn, format: :spm, bucket: 1)).to eq(1)
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
      Cluster.create(ocns: ht_item.ocns)
      insert_htitem ht_item
      ft.add_ht_item(ht_item)
      expect(ft.fetch(organization: :umich, format: :spm, bucket: 1)).to eq(1)
    end
  end

  describe "#to_json" do
    it "produces JSON String that parses to a Hash" do
      expect(ft_with_data.to_json).to be_a(String)
      expect(JSON.parse(ft_with_data.to_json)).to be_a(Hash)
    end
  end
end
