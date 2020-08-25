require "ht_members"
require "dotenv"

RSpec.describe HTMembers do
  let(:mock_umich) {
    {
      "umich" => HTMembers.template("us", 1.33, "EYM")
    }
  }

  describe "mocking" do
    it "allows you to send in mock data through new({...})" do
      htm = HTMembers.new(mock_umich)
      expect(htm.mocked).to be(true)
      expect(htm.canned).to be(false)
      expect(htm.get("umich")["country_code"]).to eq("us")
      expect(htm.get("umich")["weight"]).to eq(1.33)
      expect(htm.get("umich")["oclc_sym"]).to eq("EYM")
    end
  end

  describe "env check" do
    it "knows if the required ENV vars are set" do
      htm = HTMembers.new()
      
      ENV["MYSQL_HOST"]     = nil
      ENV["MYSQL_USERNAME"] = nil
      ENV["MYSQL_PASSWORD"] = nil
      ENV["MYSQL_PORT"]     = nil
      ENV["MYSQL_DATABASE"] = nil
      expect(htm.db_env_set?).to be(false)

      ENV["MYSQL_HOST"]     = "test1"
      ENV["MYSQL_USERNAME"] = "test2"
      ENV["MYSQL_PASSWORD"] = "test3"
      ENV["MYSQL_PORT"]     = "test4" 
      ENV["MYSQL_DATABASE"] = "test5"
      expect(htm.db_env_set?).to be(true)
    end
  end

  describe "canning" do
    it "allows you to use canned data" do
      # Which it will do if not given mock data and db_env_set? fails
      ENV["MYSQL_HOST"]     = nil
      ENV["MYSQL_USERNAME"] = nil
      ENV["MYSQL_PASSWORD"] = nil
      ENV["MYSQL_PORT"]     = nil
      ENV["MYSQL_DATABASE"] = nil
      htm = HTMembers.new()
      expect(htm.mocked).to be(false)
      expect(htm.canned).to be(true)      
      expect(htm.get("brocku")["country_code"]).to eq("ca")
      expect(htm.get("brocku")["weight"]).to eq(0.67)
      expect(htm.get("brocku")["oclc_sym"]).to eq("BRX")
    end
  end

  describe "db connection" do
    it "works and can select to populate @members" do
      Dotenv.load(".env")
      htm = HTMembers.new()
      if htm.db_env_set? then
        expect(htm.mocked).to be(false)
        expect(htm.canned).to be(false)
        expect(htm.members.size).to be > 0
        expect(htm.get("umich").nil?).to be(false)
      else
        skip "could not test db, you must set .env vars" do
          nil
        end
      end
    end
  end
  
end
