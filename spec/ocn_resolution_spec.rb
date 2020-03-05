# frozen_string_literal: true

require "ocn_resolution"

RSpec.describe OCNResolution do
  let(:deprecated) { double(:deprecated) }
  let(:resolved) { double(:resolved) }
  let(:another_ocn) { double(:another) }

  let(:resolution) { described_class.new(deprecated: deprecated, resolved: resolved) }

  it "can be created" do
    expect(resolution).to be_a(described_class)
  end

  it "returns the deprecated ocn" do
    expect(resolution.deprecated).to eq(deprecated)
  end

  it "returns the resolved ocn" do
    expect(resolution.resolved).to eq(resolved)
  end

  describe "#same_rule?" do
    it "is true if both ocns are equal" do
      expect(described_class.new(deprecated: deprecated, resolved: resolved)).to be_same_rule(resolution)
    end

    it "is not true if deprecated ocn is not equal" do
      expect(described_class.new(deprecated: another_ocn, resolved: resolved)).not_to \
        be_same_rule(resolution)
    end

    it "is not true if resolved ocn is not equal" do
      expect(described_class.new(deprecated: deprecated, resolved: another_ocn)).not_to \
        be_same_rule(resolution)
    end
  end
end
