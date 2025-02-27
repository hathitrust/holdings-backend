# frozen_string_literal: true

require "spec_helper"
require "frequency_table"

RSpec.describe FrequencyTable do
  include_context "with tables for holdings"

  let(:ft) { described_class.new }
  let(:umich_data) { {umich: {spm: {"1": 1}}} }
  let(:upenn_data) { {upenn: {spm: {"1": 1}}} }
  let(:ft_with_data) { described_class.new(data: umich_data.merge(upenn_data)) }

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
      expect(ft.frequencies(organization: :umich, format: :spm).map(&:to_a)).to eq([[1, 1]])
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

    it "returns an Array" do
      expect(freqs).to be_a(Array)
    end

    it "returns the expected frequency data" do
      expect(freqs.first).to be_a(Frequency)
      expect(freqs.map(&:to_a)).to eq([[1, 1]])
    end

    it "returns empty Array for unattested organization" do
      expect(ft1.frequencies(organization: :nobody_here_by_that_name, format: :spm)).to eq([])
    end

    it "returns empty Array for unattested format" do
      expect(ft1.frequencies(organization: :umich, format: :mpm)).to eq([])
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
      expect(ft1.append!(ft2).frequencies(organization: :umich, format: :spm).map(&:to_a)).to eq([[1, 2]])
    end

    it "adds formats" do
      ft2.increment(organization: :umich, format: :mpm, bucket: 10)
      expect(ft1.append!(ft2).frequencies(organization: :umich, format: :mpm).map(&:to_a)).to eq([[10, 1]])
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
      expect(ft1.frequencies(organization: :upenn, format: :spm).map(&:to_a)).to eq([[1, 1]])
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
      expect(ft3.frequencies(organization: :umich, format: :spm).map(&:to_a)).to eq([[1, 2]])
      expect(ft3.frequencies(organization: :upenn, format: :spm).map(&:to_a)).to eq([[1, 1]])
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
      expect(ft.frequencies(organization: :umich, format: :spm).map(&:to_a)).to eq([[1, 1]])
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
