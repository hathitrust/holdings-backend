# frozen_string_literal: true

require "spec_helper"
require "deletion/holdings_criteria"

RSpec.describe HoldingsCriteria do

  let(:params) do
    {
      organization: 'umich', 
      date_received: DateTime.parse('2022-02-07T00:00:00.000Z'),
      mono_multi_serial: 'spm'
    }
  end

  let(:criteria) { described_class.new(**params) }

  describe "initialize" do

    it "accepts a set of holdings fields" do
      expect(criteria).not_to be_nil
    end

    it "does not accept parameters that are not holdings fields" do
      expect{described_class.new(mashed_potatoes: 'no')}.to raise_exception(ArgumentError)
    end

  end

  describe "#match?" do

    it "matches a holding if all fields match" do
      h = build(:holding, **params)
      expect(criteria.match?(h)).to be true
    end

    it "does not match a holding if one mismatches" do
      criteria = described_class.new(
        organization: 'umich',
        mono_multi_serial: 'spm',
        date_received: Date.today
      )
      
      h = build(:holding, params)
      expect(criteria.match?(h)).to be false
    end

  end

  describe "#keys" do
    it "returns the keys of the criteria as strings" do
      expect(criteria.keys).to eq(["organization","date_received","mono_multi_serial"])
    end
  end

end
