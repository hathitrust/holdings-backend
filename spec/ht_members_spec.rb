require "ht_members"
require "dotenv"

RSpec.describe HTMembers do
  let(:mock_umich) {
    {
      "umich" => {
        "country_code" => "us",
        "weight"       => 1.33
      }
    }
  }

  describe "mocking" do
    it "allows you to send in mock data through new({...})" do
      htm = HTMembers.new(mock_umich)
      expect(htm.mocked).to be(true)
      expect(htm.canned).to be(false)
      expect(htm.get("umich")["country_code"]).to eq("us")
      expect(htm.get("umich")["weight"]).to eq(1.33)
    end
  end

  describe "env check" do
    it "knows if the required ENV vars are set" do
      htm = HTMembers.new()
      
      ENV["mysql_host"]     = nil
      ENV["mysql_username"] = nil
      ENV["mysql_password"] = nil
      ENV["mysql_port"]     = nil
      ENV["mysql_database"] = nil
      expect(htm.db_env_set?).to be(false)

      ENV["mysql_host"]     = "test1"
      ENV["mysql_username"] = "test2"
      ENV["mysql_password"] = "test3"
      ENV["mysql_port"]     = "test4" 
      ENV["mysql_database"] = "test5"
      expect(htm.db_env_set?).to be(true)
    end
  end

  describe "canning" do
    it "allows you to use canned data" do
      # Which it will do if not given mock data and db_env_set? fails
      ENV["mysql_host"]     = nil
      ENV["mysql_username"] = nil
      ENV["mysql_password"] = nil
      ENV["mysql_port"]     = nil
      ENV["mysql_database"] = nil
      htm = HTMembers.new()
      expect(htm.mocked).to be(false)
      expect(htm.canned).to be(true)      
      expect(htm.get("brocku")["country_code"]).to eq("ca")
      expect(htm.get("brocku")["weight"]).to eq(0.67)
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
      else
        skip "could not test db, you must set .env vars" do
          "no-op"
        end
      end
    end
  end
  
end
