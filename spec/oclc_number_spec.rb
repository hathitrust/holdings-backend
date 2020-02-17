# frozen_string_literal: true

require "oclc_number"

RSpec.describe OCLCNumber do
  let(:ocn) { rand(1_000_000).to_i }

  it "can be created" do
    expect(described_class.new(ocn)).to be_a(described_class)
  end

  it "returns the given ocn" do
    expect(described_class.new(ocn).ocn).to eq(ocn)
  end

  it "can be converted to an integer" do
    expect(described_class.new(ocn).to_i).to eq(ocn)
  end

  it "is equal to another OCLCNumber if the integer is equal" do
    expect(described_class.new(ocn)).to eq(described_class.new(ocn))
  end
end
