# frozen_string_literal: true

require "spec_helper"
require "overlap/report_record"

RSpec.describe Overlap::ReportRecord do
  let(:holding) { build(:holding, mono_multi_serial: "spm") }
  let(:ht_item) { build(:ht_item, :spm, rights: "ic") }
  let(:eo) do
    described_class.new(holding: holding, ht_item: ht_item)
  end

  describe "#initialize" do
    it "has a local_id" do
      expect(eo.local_id).to be_a(String)
    end

    it "has an OCLC" do
      expect(eo.ocn).to be_a(Numeric)
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
      expect(eo.catalog_id).to be_a(Numeric)
    end

    it "has a volume_id" do
      expect(eo.volume_id).to be_a(String)
    end

    it "has an enum_chron" do
      expect(eo.enum_chron).to be_a(String)
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
