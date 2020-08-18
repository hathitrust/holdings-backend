# frozen_string_literal: true

require "ht_members"
require "dotenv"

RSpec.describe HTMembers do
  let(:mock_data) do
    {
      "example" => HTMember.new(inst_id: "example", country_code: "xx",
                                weight: 3.5, oclc_sym: "ZZZ")
    }
  end

  describe "mocking" do
    it "can accept mocked data" do
      htm = described_class.new(mock_data)
      expect(htm["example"].country_code).to eq("xx")
      expect(htm["example"].weight).to eq(3.5)
      expect(htm["example"].oclc_sym).to eq("ZZZ")
    end
  end

  describe "db connection" do
    it "can fetch data from the database" do
      htm = described_class.new
      expect(htm["umich"].country_code).to eq("us")
      expect(htm["umich"].weight).to eq(1.33)
      expect(htm["umich"].oclc_sym).to eq("EYM")
    end

    it "can fetch the full hash" do
      htm = described_class.new
      expect(htm.members.size).to be > 0
    end
  end
end
