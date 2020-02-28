# frozen_string_literal: true

require "oclc_cluster"

RSpec.describe OCLCCluster do
  let(:ocn1) { rand(1_000_000).to_i }
  let(:ocn2) { rand(1_000_000).to_i }

  it "can be created" do
    expect(described_class.new([ocn1, ocn2])).to be_a(described_class)
    expect(described_class.new([ocn1, ocn2]).first).to be_a(OCLCNumber)
    expect(described_class.new([ocn1, ocn2]).first.ocn).to be(ocn1)
  end

  it "can be created from an OCLCNumber" do
    expect(described_class.new([OCLCNumber.new(5)])).to be_a(described_class)
    expect(described_class.new([OCLCNumber.new(5)]).first).to be_a(OCLCNumber)
    expect(described_class.new([OCLCNumber.new(5)]).first.ocn).to be(5)
  end

  it "returns ocns as array of OCLCNumber" do
    expect(described_class.new([ocn1, ocn2]).to_a).to\
      eq([OCLCNumber.new(ocn1), OCLCNumber.new(ocn2)])
  end

  it "has a method to convert to database friendly" do
    expect(described_class.new([ocn1]).mongoize.class).to eq(Array)
  end

  it "mongoizes the OCLCNumbers too" do
    expect(described_class.new([ocn1]).mongoize.first.class).to eq(Integer)
  end

  it "has a method to convert from array of integers when pulling from database" do
    expect(described_class.demongoize([ocn1]).class).to eq(described_class)
  end

  it "converts the integers to OCLCNumbers too" do
    expect(described_class.demongoize([ocn1]).first.class).to eq(OCLCNumber)
  end

  it "can mongoize any object" do
    expect(described_class.mongoize(described_class.new([ocn1])).class).to\
      eq(Array)
  end
end
