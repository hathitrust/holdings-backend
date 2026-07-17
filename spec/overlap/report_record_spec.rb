# frozen_string_literal: true

require "spec_helper"
require "overlap/report_record"

RSpec.describe Overlap::ReportRecord do
  let(:holding) { build(:holding, mono_multi_serial: "spm") }
  let(:ht_item) { build(:ht_item, :spm, rights: "ic") }
  let(:eo) do
    described_class.new(holdings: [holding], ht_item: ht_item, organization: holding.organization)
  end

  describe "#initialize" do
    it "has a local_id" do
      expect(eo.local_id).to be_a(String)
    end

    it "has an OCLC" do
      expect(eo.ocn).to eq(holding.ocn.to_s)
    end

    it "has an item_type" do
      expect(["mix", "mon", "spm", "mpm", "ser"].include?(eo.item_type)).to be true
    end

    it "has an access" do
      expect(eo.access).to eq("deny")
    end

    it "has a rights" do
      expect(eo.rights).to eq("ic")
    end

    it "has a catalog_id" do
      expect(eo.catalog_id).to eq(ht_item.ht_bib_key)
    end

    it "has a volume_id" do
      expect(eo.volume_id).to eq(ht_item.item_id)
    end

    it "has an enum_chron" do
      expect(eo.enum_chron).to eq(ht_item.enum_chron)
    end
  end

  context "with multiple holdings" do
    it "gathers unique ocns" do
      report_record = described_class.new(holdings: [
        build(:holding, ocn: 99, organization: "upenn"),
        build(:holding, ocn: 99, organization: "upenn"),
        build(:holding, ocn: 98, organization: "upenn")
      ], organization: "upenn")

      expect(report_record.ocn).to eq("98,99")
    end

    it "gathers unique local ids" do
      report_record = described_class.new(holdings: [
        build(:holding, local_id: "local_id_1", organization: "upenn"),
        build(:holding, local_id: "local_id_2", organization: "upenn"),
        build(:holding, local_id: "local_id_1", organization: "upenn")
      ], organization: "upenn")

      expect(report_record.local_id).to eq("local_id_1,local_id_2")
    end
  end

  describe "#convert_access" do
    it "returns whatever it was given for US orgs" do
      expect(eo.convert_access(nil, "given", "smu")).to eq("given")
    end

    it "returns 'deny' if rights is 'pdus' for non-US orgs" do
      expect(eo.convert_access("pdus", "allow", "uct")).to eq("deny")
    end

    it "returns 'allow' if rights is 'icus' for non-US orgs" do
      expect(eo.convert_access("icus", "deny", "uct")).to eq("allow")
    end

    it "returns whatever it was given if rights is not 'icus' or 'pdus' for non-US orgs" do
      expect(eo.convert_access(nil, "given", "uct")).to eq("given")
    end
  end

  describe "#to_s" do
    it "creates a report record in order: ocn, local_id, item_type, rights, access, catalog_id,
         volume_id, enum_chron" do
           record = "#{eo.ocn}\t#{eo.local_id}\tspm\tic\tdeny" \
             "\t#{eo.catalog_id}\t#{eo.volume_id}\t"
           expect(eo.to_s).to eq(record)
         end
  end
end
