# frozen_string_literal: true

require "spec_helper"
require "clusterable/holding"
require "cluster"

RSpec.describe Clusterable::Holding do
  let(:c) { create(:cluster) }
  let(:h) { build(:holding, :all_fields) }
  let(:h2) { h.clone }

  it "does not have a parent" do
    expect(build(:holding)._parent).to be_nil
  end

  it "has a parent" do
    c.holdings << build(:holding)
    expect(c.holdings.first._parent).to be(c)
  end

  it "normalizes enum_chron" do
    holding = build(:holding, enum_chron: "v.1 Jul 1999")
    expect(holding.n_enum).to eq("1")
    expect(holding.n_chron).to eq("Jul 1999")
    expect(holding.n_enum_chron).to eq("1\tJul 1999")
  end

  it "does nothing if given an empty enum_chron" do
    holding = build(:holding, enum_chron: "")
    expect(holding.n_enum).to eq("")
    expect(holding.n_chron).to eq("")
    expect(holding.n_enum_chron).to eq("")
  end

  describe "#==" do
    it "== is true if all fields match except date_received and uuid" do
      h2.date_received = Date.yesterday
      h2.uuid = SecureRandom.uuid
      expect(h).to eq(h2)
    end

    it "== is true if all fields match including date_received" do
      expect(h).to eq(h2)
    end

    it "== is true if corresponding fields are nil vs. empty string" do
      h.issn = nil
      h.n_enum = nil
      h.n_chron = nil
      h.condition = nil

      h2.issn = ""
      h2.n_enum = ""
      h2.n_chron = ""
      h2.condition = ""
      expect(h).to eq(h2)
    end

    (described_class.fields.keys - ["date_received", "uuid", "_id"]).each do |attr|
      it "== is false if #{attr} doesn't match" do
        # ensure attribute in h2 is different from h but 
        # of the same logical type
        #
        case h[attr]
        when String
          h2[attr] = "#{h[attr]}junk"
        when Numeric
          h2[attr] = h[attr] + 1
        when true, false, nil
          h2[attr] = !h[attr]
        end

        expect(h[attr]).not_to eq(h2[attr])
        expect(h).not_to eq(h2)
      end
    end
  end

  describe "#same_as?" do
    let(:h2) { h.clone }

    it "same_as is true if all fields match" do
      expect(h).to be_same_as(h2)
    end

    it "same_as is not true if date_received does not match" do
      h2.date_received = Date.yesterday
      expect(h).not_to be_same_as(h2)
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
      line = "100000252\t005556200\tumich\tCH\t\t2019-10-24\t\tspm\t\t\t\t0"
      rec = described_class.new_from_holding_file_line(line)
      expect(rec).to be_a(described_class)
      expect(rec.mono_multi_serial).to eq("spm")
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
