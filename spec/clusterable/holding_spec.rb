# frozen_string_literal: true

require "spec_helper"
require "clusterable/holding"
require "cluster"

RSpec.describe Clusterable::Holding do
  let(:holdings_org) { "umich" }
  let(:h) { build(:holding, :all_fields, organization: holdings_org) }
  let(:h2) { h.clone }

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

  describe "#batch_add" do
    include_context "with tables for holdings"

    it "inserts multiple holdings" do
      described_class.batch_add([build(:holding), build(:holding)])
      expect(Services.holdings_table.count).to eq(2)
    end

    it "ignores duplicate holdings" do
      described_class.batch_add([h])
      expect(Services.holdings_table.count).to eq(1)
      described_class.batch_add([h, build(:holding)])
      expect(Services.holdings_table.count).to eq(2)
    end
  end

  describe "#cluster" do
    include_context "with tables for holdings"

    it "can get the cluster with the holding ocn" do
      load_test_data(
        build(:ht_item, ocns: [1001, 1002]),
        build(:ocn_resolution, canonical: 1001, variant: 1003)
      )

      holding = build(:holding, ocn: 1001)
      expect(holding.cluster.ocns).to contain_exactly(1001, 1002, 1003)
    end

    it "can be provided to the constructor" do
      c = double(:cluster)
      h = described_class.new({cluster: c})
      expect(h.cluster).to eq(c)
    end
  end

  describe "#==" do
    it "== is true if all fields match except date_received and uuid" do
      h2.date_received = Date.today - 1
      h2.uuid = SecureRandom.uuid
      expect(h).to eq(h2)
    end

    it "== is true if all fields match including date_received" do
      expect(h).to eq(h2)
    end

    context "when one holding has nil attrs and the other has empty string" do
      before(:each) do
        [:n_enum=, :n_chron=, :condition=, :issn=].each do |setter|
          h.public_send(setter, "")
          h2.public_send(setter, nil)
        end
      end

      it "== is true" do
        expect(h).to eq(h2)
      end

      it "update_key is the same" do
        expect(h.update_key).to eq(h2.update_key)
      end
    end

    described_class.equality_attrs.each do |attr|
      it "== is false if #{attr} doesn't match" do
        # ensure attribute in h2 is different from h but
        # of the same logical type

        case h.send(attr)
        when holdings_org
          # need to have an actual organization
          h2.send(attr.to_s + "=", "upenn")
        when String
          h2.send(attr.to_s + "=", "#{h.send(attr)}junk")
        when Numeric
          h2.send(attr.to_s + "=", h.send(attr) + 1)
        when true, false, nil
          h2.send(attr.to_s + "=", !h.send(attr))
        end

        expect(h.send(attr)).not_to eq(h2.send(attr))
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
      h2.date_received = Date.today - 1
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

  describe "#{described_class}.holding_to_record" do
    # Prepares strings from the old style holdings file format
    # (HT003_#{organization}.#{mono_multi_serial}.tsv) for loading.
    # ht003_ser_str has no status, no uuid and its mono_multi_serial is outdated
    let(:ht003_mon_str) { "1\t99106\tallegheny\tCH\t\t2020-09-29\t\tmono\t\t\t\t0" }
    let(:ht003_mul_str) { "2\t99106\tallegheny\tCH\t\t2020-09-29\tv.1\tmulti\t\t1\t\t0" }
    let(:ht003_ser_str) { "3\t99106\tallegheny\t\t\t2020-09-29\t\tserial\t\t\t\t0" }
    let(:fixed_mon_cols) { described_class.holding_to_record(ht003_mon_str) }
    let(:fixed_mul_cols) { described_class.holding_to_record(ht003_mul_str) }
    let(:fixed_ser_cols) { described_class.holding_to_record(ht003_ser_str) }

    it "adds status if missing" do
      expect(fixed_ser_cols[:status]).to eq "CH"
    end
    it "adds uuid if missing" do
      expect(fixed_ser_cols[:uuid]).to match(/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/)
    end
    it "fixes mono_multi_serial if outdated" do
      expect(fixed_mon_cols[:mono_multi_serial]).to eq "spm"
      expect(fixed_mul_cols[:mono_multi_serial]).to eq "mpm"
      expect(fixed_ser_cols[:mono_multi_serial]).to eq "ser"
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

  describe "#brt_lm_access?" do
    it "is true if holding has status:LM and/or condition:BRT" do
      status_values = ["CH", "LM", "WD", nil]
      condition_values = ["BRT", ""]
      test_count = 0
      true_count = 0
      false_count = 0

      status_values.each do |status|
        condition_values.each do |condition|
          holding = build(:holding, status: status, condition: condition)
          test_count += 1
          if condition == "BRT" || status == "LM"
            true_count += 1
            expect(holding.brt_lm_access?).to be true
          else
            false_count += 1
            expect(holding.brt_lm_access?).to be false
          end
        end
      end
      expect(test_count).to eq 8
      expect(true_count).to eq 5
      expect(false_count).to eq 3
    end
  end
end
