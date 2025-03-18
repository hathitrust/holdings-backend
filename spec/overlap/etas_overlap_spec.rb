# frozen_string_literal: true

require "spec_helper"
require "overlap/etas_overlap"

RSpec.describe Overlap::ETASOverlap do
  let(:eo) do
    described_class.new(organization: "umich",
      ocn: rand(1_000_000),
      local_id: rand(1_000_000).to_s,
      item_type: "spm",
      rights: "ic",
      access: "deny",
      catalog_id: rand(1_000_000),
      volume_id: rand(1_000_000).to_s,
      enum_chron: "V.1")
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
      expect(["deny", "allow"].include?(eo.access)).to be true
    end

    it "has a rights" do
      expect(["pd", "ic", "und"].include?(eo.rights)).to be true
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
             "\t#{eo.catalog_id}\t#{eo.volume_id}\tV.1"
           expect(eo.to_s).to eq(record)
         end
  end
end
