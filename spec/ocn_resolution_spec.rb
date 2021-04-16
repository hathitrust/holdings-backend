# frozen_string_literal: true

require "spec_helper"
require "ocn_resolution"

RSpec.describe OCNResolution do
  let(:deprecated) { double(:deprecated) }
  let(:resolved) { double(:resolved) }
  let(:another_ocn) { double(:another) }

  let(:resolution) do
    described_class.new(deprecated: deprecated, resolved: resolved)
  end

  it "can be created" do
    expect(resolution).to be_a(described_class)
  end

  it "returns the deprecated ocn" do
    expect(resolution.deprecated).to eq(deprecated)
  end

  it "returns the resolved ocn" do
    expect(resolution.resolved).to eq(resolved)
  end

  it "returns both ocns" do
    expect(resolution.ocns).to eq([deprecated, resolved])
  end

  describe "==" do
    it "is equal if both ocns are the same" do
      expect(described_class.new(deprecated: deprecated, resolved: resolved))
        .to eq(described_class.new(deprecated: deprecated, resolved: resolved))
    end
  end

  describe "#batch_with?" do
    let(:resolution1) { build(:ocn_resolution, deprecated: 123, resolved: 456) }
    let(:resolution2) { build(:ocn_resolution, deprecated: 312, resolved: 456) }
    let(:resolution3) { build(:ocn_resolution, deprecated: 123, resolved: 789) }

    it "batches items with the same resolved OCN" do
      expect(resolution1.batch_with?(resolution2)).to be true
    end

    it "does not batch items with different deprecated and resolved OCNS" do
      expect(resolution2.batch_with?(resolution3)).to be false
    end

    it "does not batch items with the same deprecated but different resolved OCN" do
      expect(resolution1.batch_with?(resolution3)).to be false
    end
  end
end
