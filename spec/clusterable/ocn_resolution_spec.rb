# frozen_string_literal: true

require "spec_helper"
require "clusterable/ocn_resolution"

RSpec.describe Clusterable::OCNResolution do
  let(:variant) { double(:variant) }
  let(:canonical) { double(:canonical) }
  let(:another_ocn) { double(:another) }

  let(:resolution) do
    described_class.new(variant: variant, canonical: canonical)
  end

  it "can be created" do
    expect(resolution).to be_a(described_class)
  end

  it "returns the variant ocn" do
    expect(resolution.variant).to eq(variant)
  end

  it "returns the canonical ocn" do
    expect(resolution.canonical).to eq(canonical)
  end

  it "returns both ocns" do
    expect(resolution.ocns).to eq([variant, canonical])
  end

  describe "==" do
    it "is equal if both ocns are the same" do
      expect(described_class.new(variant: variant, canonical: canonical))
        .to eq(described_class.new(variant: variant, canonical: canonical))
    end
  end

  describe "#batch_with?" do
    let(:resolution1) { build(:ocn_resolution, variant: 123, canonical: 456) }
    let(:resolution2) { build(:ocn_resolution, variant: 312, canonical: 456) }
    let(:resolution3) { build(:ocn_resolution, variant: 123, canonical: 789) }

    it "batches items with the same canonical OCN" do
      expect(resolution1.batch_with?(resolution2)).to be true
    end

    it "does not batch items with different variant and canonical OCNS" do
      expect(resolution2.batch_with?(resolution3)).to be false
    end

    it "does not batch items with the same variant but different canonical OCN" do
      expect(resolution1.batch_with?(resolution3)).to be false
    end
  end
end
