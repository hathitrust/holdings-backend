# frozen_string_literal: true

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
end
