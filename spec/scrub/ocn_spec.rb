# frozen_string_literal: true

require "scrub/ocn"

RSpec.describe Scrub::Ocn do
  it "takes a string and returns an array of numbers if OK" do
    expect(described_class.new("1").value).to eq [1]
  end

  it "uniqs numbers" do
    expect(described_class.new("1").value).to eq [1]
    expect(described_class.new("1,1").value).to eq [1]
    expect(described_class.new("1,2").value).to eq [1, 2]
  end

  it "rejects nil input by raising error" do
    expect { described_class.new(nil).value }.to raise_error ArgumentError
  end

  it "returns empty array if given empty string" do
    expect(described_class.new("").value).to eq []
  end

  it "returns empty array if given an exponential number" do
    expect(described_class.new("1.0E+10").value).to eq []
  end

  it "returns empty array if given an unparseable mix of digits and alphas" do
    expect(described_class.new("a1a").value).to eq []
    expect(described_class.new("1a1").value).to eq []
  end

  it "returns empty array if given bad prefix" do
    expect(described_class.new("foo1").value).to eq []
    expect(described_class.new("(foo)1").value).to eq []
  end

  it "returns empty array if given a number too large to be an OCN" do
    expect(described_class.new("999999999999999").value).to eq []
  end

  it "returns empty array if the numeric part is zero" do
    expect(described_class.new("0").value).to eq []
  end

  it "splits on certain delimiters" do
    expect(described_class.new("1,2:3;4|5/6 7").value).to eq [1, 2, 3, 4, 5, 6, 7]
  end

  it "allows certain prefixes" do
    expect(described_class.new("oclc1,ocm2,ocn3,ocolc4,on5").value).to eq [1, 2, 3, 4, 5]
  end

  it "allows parens around prefixes" do
    expect(described_class.new("(oclc)1,(ocm)2,(ocn)3,(ocolc)4,(on)5").value).to eq [1, 2, 3, 4, 5]
  end
end
