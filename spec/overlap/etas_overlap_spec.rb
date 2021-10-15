# frozen_string_literal: true

require "spec_helper"
require "overlap/etas_overlap"

RSpec.describe Overlap::ETASOverlap do
  let(:eo) do
    described_class.new(ocn: rand(1_000_000),
              local_id: rand(1_000_000).to_s,
              item_type: "spm",
              rights: "ic",
              access: "deny")
  end

  describe "#initialize" do
    it "has a local_id" do
      expect(eo.local_id).to be_a(String)
    end

    it "has an OCLC" do
      expect(eo.ocn).to be_a(Numeric)
    end

    it "has an item_type" do
      expect(eo.item_type).to be_in(["mono", "multi", "serial"])
    end

    it "has an access" do
      expect(eo.access).to be_in(["deny", "allow"])
    end

    it "has a rights" do
      expect(eo.rights).to be_in(["pd", "ic", "und"])
    end
  end

  describe "#to_s" do
    it "creates a report record in order: ocn, local_id, item_type, rights, access" do
      expect(eo.to_s).to eq("#{eo.ocn}\t#{eo.local_id}\tmono\tic\tdeny")
    end
  end

  describe "convert_format" do
    it "maps spm to mono, mpm to multi, ser and ser/spm to serial" do
      expect(eo.convert_format("spm")).to eq("mono")
      expect(eo.convert_format("mpm")).to eq("multi")
      expect(eo.convert_format("ser")).to eq("serial")
      expect(eo.convert_format("ser/spm")).to eq("serial")
    end
  end
end
