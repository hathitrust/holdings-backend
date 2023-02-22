# frozen_string_literal: true

require "spec_helper"
require "data_sources/holdings_db"

RSpec.describe DataSources::HoldingsDB do
  let(:connection_string) { "mysql2://ht_repository:ht_repository@mariadb/ht_repository" }
  let(:user) { "ht_repository" }
  let(:password) { "ht_repository" }
  let(:database) { "ht_repository" }
  let(:host) { "mariadb" }
  let(:connection) do
    described_class.new(user: user,
      password: password,
      database: database,
      host: host)
  end

  let(:opts) do
    {user: user,
     password: password,
     host: host,
     database: database,
     adapter: "mysql2"}
  end

  describe "Connecting" do
    it "connects with url" do
      c = described_class.connection(url: connection_string)
      expect(c.tables).to include(:ht_billing_members)
    end

    it "connects with opts" do
      c = described_class.connection(opts: opts)
      expect(c.tables).to include(:ht_billing_members)
    end

    it "connects with url" do
      Settings.database = {url: connection_string}
      c = described_class.connection
      expect(c.tables).to include(:ht_billing_members)
    end

    it "connects with keyword options" do
      Settings.database = {opts: opts}
      c = described_class.connection
      expect(c.tables).to include(:ht_billing_members)
    end

    it "fails as expected with bad user" do
      Settings.database = {opts: opts.merge(user: "NO_SUCH_USER")}
      expect { described_class.connection }.to raise_error(Sequel::DatabaseConnectionError)
    end

    it "provided opts override settings" do
      Settings.database = {opts: opts.merge(user: "NO_SUCH_USER")}
      c = described_class.connection(opts: opts)
      expect(c.tables).to include(:ht_billing_members)
    end
  end

  describe "Data is loaded" do
    it "finds all the institutions" do
      c = described_class.connection
      expect(c[:ht_billing_members].count).to equal(197)
    end
  end
end
