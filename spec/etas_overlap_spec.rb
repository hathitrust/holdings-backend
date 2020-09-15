# frozen_string_literal: true

require "spec_helper"
require "etas_overlap"

RSpec.describe ETASOverlap do
  let(:eo) do
    described_class.new(ocn: rand(1_000_000),
              local_id: rand(1_000_000).to_s,
              item_type: "spm",
              access: "deny",
              rights: "ic")
  end

  describe "#initialize" do
    it "has a local_id" do
      expect(eo.local_id).to be_a(String)
    end

    it "has an OCLC" do
      expect(eo.ocn).to be_a(Numeric)
    end

    it "has an item_type" do
      expect(eo.item_type).to be_in(["spm", "mpm", "ser"])
    end

    it "has an access" do
      expect(eo.access).to be_in(["deny", "allow"])
    end

    it "has a rights" do
      expect(eo.rights).to be_in(["pd", "ic", "und"])
    end
  end

  describe "#to_s" do
    it "creates a report record" do
      expect(eo.to_s).to eq("#{eo.ocn}\t#{eo.local_id}\tspm\tdeny\tic")
    end
  end
end
