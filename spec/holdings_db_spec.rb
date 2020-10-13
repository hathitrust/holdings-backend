# frozen_string_literal: true

require "spec_helper"
require "holdings_db"

RSpec.describe HoldingsDB do
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

  let(:env_mapping) do
    { "DB_USER"     => user,
      "DB_PASSWORD" => password,
      "DB_HOST"     => host,
      "DB_DATABASE" => database,
      "DB_ADAPTER"  => "mysql2" }
  end

  def wipe_env
    env_mapping.each_key {|x| ENV.delete(x) }
    ENV.delete("DB_CONNECTION_STRING")
  end

  def set_env
    env_mapping.each_pair do |k, v|
      ENV[k] = v
    end
  end

  describe "Connecting" do
    it "connects with connection string" do
      c = described_class.connection(connection_string)
      expect(c.tables).to include(:ht_institutions)
    end

    it "connects with piecemeal keyword args" do
      c = described_class.connection(user: user, password: password, database: database, host: host)
      expect(c.tables).to include(:ht_institutions)
    end

    context "with clean environment" do
      around :each do |example|
        old_env = ENV.to_h
        wipe_env

        example.run

        old_env.each {|k, v| ENV[k] = v }
      end

      it "connects with ENV connection string" do
        ENV["DB_CONNECTION_STRING"] = connection_string
        c                           = described_class.connection
        expect(c.tables).to include(:ht_institutions)
      end

      it "connects with ENV settings" do
        set_env
        c = described_class.connection
        expect(c.tables).to include(:ht_institutions)
      end

      it "fails as expected with bad env" do
        set_env
        ENV["DB_USER"] = "NO_SUCH_USER"
        expect { described_class.connection }.to raise_error(Sequel::DatabaseConnectionError)
      end

      it "allows override of ENV" do
        set_env
        ENV["DB_USER"] = "NO_SUCH_USER"
        c = described_class.connection(user: user)
        expect(c.tables).to include(:ht_institutions)
      end
    end
  end

  describe "Data is loaded" do
    it "finds all the institutions" do
      c = described_class.connection(user: user, password: password, database: database, host: host)
      expect(c[:ht_institutions].count).to equal(249)
    end
  end
end
