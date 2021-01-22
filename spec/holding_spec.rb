# frozen_string_literal: true

require "holding"
require "cluster"
require "spec_helper"

RSpec.describe Holding do
  let(:c) { create(:cluster) }
  let(:h) { build(:holding) }
  let(:h2) { h.clone }

  it "does not have a parent" do
    expect(build(:holding)._parent).to be_nil
  end

  it "has a parent" do
    c.holdings << build(:holding)
    expect(c.holdings.first._parent).to be(c)
  end

  it "normalizees enum_chron" do
    holding = build(:holding, enum_chron: "v.1 Jul 1999")
    expect(holding.n_enum).to eq("1")
    expect(holding.n_chron).to eq("Jul 1999")
    expect(holding.n_enum_chron).to eq("1 Jul 1999")
  end

  it "does nothing if given an empty enum_chron" do
    holding = build(:holding, enum_chron: "")
    expect(holding.n_enum).to eq("")
    expect(holding.n_chron).to eq("")
    expect(holding.n_enum_chron).to eq("")
  end

  describe "#==" do
    it "== is true if all fields match except date_received" do
      h2.date_received = Date.yesterday
      expect(h == h2).to be(true)
    end

    it "== is true if all fields match including date_received" do
      expect(h == h2).to be(true)
    end
  end

  describe "#same_as?" do
    let(:h2) { h.clone }

    it "same_as is true if all fields match" do
      expect(h.same_as?(h2)).to be(true)
    end

    it "same_as is not true if date_received does not match" do
      h2.date_received = Date.yesterday
      expect(h.same_as?(h2)).to be(false)
    end
  end

  describe "#country_code" do
    it "is automatically set when organization is set" do
      expect(build(:holding, organization: "ualberta").country_code).to eq("ca")
    end
  end

  describe "#weight" do
    it "is automatically set when organization is set" do
      expect(build(:holding, organization: "utexas").weight).to eq(3.0)
    end
  end

  describe "#new_from_holding_file_line" do
    it "turns a holdings file line into a new Holding" do
      line = "100000252\t005556200\tumich\tCH\t\t2019-10-24\t\tmono\t\t\t\t0"
      rec = described_class.new_from_holding_file_line(line)
      expect(rec).to be_a(described_class)
      expect(rec.mono_multi_serial).to eq("mono")
      expect(rec.n_enum).to eq("")
    end
  end

  describe "#batch_with?" do
    let(:holding1) { build(:holding, ocn: 123) }
    let(:holding2) { build(:holding, ocn: 123) }
    let(:holding3) { build(:holding, ocn: 456) }

    it "batches with a holding with the same ocn" do
      expect(holding1.batch_with?(holding2)).to be true
    end

    it "doesn't batch with a holding with a different ocn" do
      expect(holding1.batch_with?(holding3)).to be false
    end
  end

  describe "#inspect" do
    it "shows the ocn" do
      expect(h.inspect).to match(h.ocn.to_s)
    end

    it "shows the uuid" do
      expect(h.inspect).to match(h.uuid)
    end

    it "shows the member" do
      expect(h.inspect).to match(h.organization)
    end
  end
end
