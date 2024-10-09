# frozen_string_literal: true

require "spec_helper"
require "deletion/composite_holdings_criteria"
require "deletion/holdings_criteria.rb"

RSpec.describe CompositeHoldingsCriteria do

  let(:criteria1) { HoldingsCriteria.new(ocn: 1, organization: "umich") }
  let(:criteria2) { HoldingsCriteria.new(organization: "smu", ocn: 2) }
  let(:composite) { described_class.new(criteria1, criteria2) }

  describe "initialize" do
    it "accepts an array of HoldingsCriteria" do 
      expect(composite).not_to be nil
    end

    it "raises ArgumentError if the criteria individually have different fields" do
      expect { described_class.new(criteria1,HoldingsCriteria.new(ocn: 4)) }.to raise_exception(ArgumentError)
    end
  end

  describe "#match?" do
    it "matches a holding if one of the criteria match" do
      expect(composite.match?(build(:holding, ocn: 1, organization: "umich"))).to be true
    end

    it "does not match a holding if none of the criteria match" do
      expect(composite.match?(build(:holding, ocn: 3, organization: "umich"))).to be false
    end
  end
end
