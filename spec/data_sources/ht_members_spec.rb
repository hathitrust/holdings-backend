# frozen_string_literal: true

require "spec_helper"
require "data_sources/ht_members"

RSpec.describe DataSources::HTMembers do
  let(:mock_data) do
    {
      "example" => DataSources::HTMember.new(inst_id: "example", country_code: "xx",
                                weight: 3.5, oclc_sym: "ZZZ")
    }
  end

  let(:ht_members) { described_class.new(mock_data) }

  let(:temp_member) do
    DataSources::HTMember.new(inst_id: "temp", country_code: "zz", weight: 1.0)
  end

  describe "#[]" do
    it "can fetch an institution" do
      expect(ht_members["example"].country_code).to eq("xx")
      expect(ht_members["example"].weight).to eq(3.5)
      expect(ht_members["example"].oclc_sym).to eq("ZZZ")
    end

    it "raises a KeyError when institution has no data" do
      expect { ht_members["nonexistent"] }.to raise_exception(KeyError)
    end
  end

  describe "#members" do
    it "returns all members as a hash" do
      expect(ht_members.members.keys).to contain_exactly("example")
    end
  end

  describe "#add_temp" do
    it "can add a temporary institution" do
      expect(ht_members.add_temp(temp_member)).not_to be(nil)
    end

    it "can fetch a temporary institution" do
      ht_members.add_temp(temp_member)

      expect(ht_members["temp"].country_code).to eq("zz")
    end
  end

  describe "db connection" do
    let(:ht_members) { described_class.new }

    # Ensure we have a clean database connection for each test
    around(:each) do |example|
      old_holdings_db = Services.holdings_db
      Services.register(:holdings_db) { DataSources::HoldingsDB.connection }
      begin
        example.run
      ensure
        Services.register(:holdings_db) { old_holdings_db }
      end
    end

    it "can fetch data from the database" do
      expect(ht_members["umich"].country_code).to eq("us")
      expect(ht_members["umich"].weight).to eq(1.33)
      expect(ht_members["umich"].oclc_sym).to eq("EYM")
    end

    it "can fetch the full set of members" do
      expect(ht_members.members.size).to be > 10
    end

    it "does not persist temp members to the database/across instances" do
      ht_members.add_temp(temp_member)

      expect(described_class.new.members.key?("temp")).to be false
    end
  end

  describe DataSources::HTMember do
    describe "#initialize" do
      it "raises an error if no inst_id" do
        expect { described_class.new(inst_id: nil) }.to raise_exception("Must have institution id")
      end

      it "raises an error if no weight" do
        expect { described_class.new(inst_id: "example", weight: nil) }.to \
          raise_exception("Weight must be between 0 and 10")
      end
    end
  end
end
