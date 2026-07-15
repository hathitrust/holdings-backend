require "overlap/item_non_current_holdings"

RSpec.describe Overlap::ItemNonCurrentHoldings do
  include_context "with tables for holdings"

  describe "#non_current_holdings" do
    let(:ht_item) { build(:ht_item, :spm, collection_code: "MIU") }
    let(:non_current_holdings) { described_class.new(ht_item).non_current_holdings }

    it "can analyze an spm where one org holds a withdrawn item" do
      load_test_data(
        ht_item,
        holding_for(ht_item, organization: "umich", status: "WD")
      )

      expect(non_current_holdings.to_h).to eq({"umich" => :withdrawn})
    end

    it "can analyze an spm where one org holds a withdrawn item and one has a current holding" do
      load_test_data(
        ht_item,
        holding_for(ht_item, organization: "umich", status: "WD"),
        holding_for(ht_item, organization: "upenn", status: "CH")
      )

      expect(non_current_holdings.to_h).to eq({"umich" => :withdrawn})
    end

    it "returns an empty hash for an org with a withdrawn item and a current holding" do
      load_test_data(
        ht_item,
        holding_for(ht_item, organization: "umich", status: "WD"),
        holding_for(ht_item, organization: "umich", status: "CH")
      )

      expect(non_current_holdings.to_h).to eq({})
    end

    it "returns 'brittle' for an org with a brittle item" do
      load_test_data(
        ht_item,
        holding_for(ht_item, organization: "umich", condition: "BRT")
      )

      expect(non_current_holdings.to_h).to eq({"umich" => :brittle})
    end

    it "returns empty for an org with a brittle item and a current item" do
      load_test_data(
        ht_item,
        holding_for(ht_item, organization: "umich", condition: "BRT"),
        holding_for(ht_item, organization: "umich", status: "CH")
      )

      expect(non_current_holdings.to_h).to eq({})
    end

    it "returns 'multiple' for an org with a withdrawn and a brittle item" do
      load_test_data(
        ht_item,
        holding_for(ht_item, organization: "umich", condition: "BRT"),
        holding_for(ht_item, organization: "umich", status: "WD")
      )

      expect(non_current_holdings.to_h).to eq({"umich" => :multiple})
    end

    it "returns 'multiple' for an org with a withdrawn, lost/missing, and brittle items" do
      load_test_data(
        ht_item,
        holding_for(ht_item, organization: "umich", condition: "BRT"),
        holding_for(ht_item, organization: "umich", status: "WD"),
        holding_for(ht_item, organization: "umich", status: "LM")
      )

      expect(non_current_holdings.to_h).to eq({"umich" => :multiple})
    end

    it "returns empty for an org with current, withdrawn, lost/missing, and brittle items" do
      load_test_data(
        ht_item,
        holding_for(ht_item, organization: "umich", condition: "BRT"),
        holding_for(ht_item, organization: "umich", status: "CH"),
        holding_for(ht_item, organization: "umich", status: "WD"),
        holding_for(ht_item, organization: "umich", status: "LM")
      )

      expect(non_current_holdings.to_h).to eq({})
    end

    it "returns 'lost_missing' for an org with a lost/missing item" do
      load_test_data(
        ht_item,
        holding_for(ht_item, organization: "umich", status: "LM")
      )

      expect(non_current_holdings.to_h).to eq({"umich" => :lost_missing})
    end

    it "returns different conditions for multiple organizations with non-current holdings" do
      load_test_data(
        ht_item,
        holding_for(ht_item, organization: "umich", status: "CH"),
        holding_for(ht_item, organization: "upenn", status: "WD"),
        holding_for(ht_item, organization: "smu", status: "LM")
      )

      expect(non_current_holdings.to_h).to eq({
        "upenn" => :withdrawn,
        "smu" => :lost_missing
      })
    end
  end
end
