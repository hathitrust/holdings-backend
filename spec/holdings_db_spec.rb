# frozen_string_literal: true

require "spec_helper"
require 'holdings_db'

RSpec.describe HoldingsDB do
  let(:connection_string) { 'mysql2://ht_repository:ht_repository@mariadb/ht_repository' }
  let(:user) { 'ht_repository' }
  let(:password) { 'ht_repository' }
  let(:database) { 'ht_repository' }
  let(:host) { 'mariadb' }
  let(:connection) { HoldingsDB.connection(user: user, password: password, database: database, host: host) }

  let(:env_mapping)  {
      {'DB_USER'     => user,
       'DB_PASSWORD' => password,
       'DB_HOST'     => host,
       'DB_DATABASE' => database,
       'DB_ADAPTER'  => 'mysql2'}
  }

  def wipe_env
    env_mapping.keys.each { |x| ENV.delete(x) }
    ENV.delete('DB_CONNECTION_STRING')
  end

  def set_env
    env_mapping.each_pair do |k, v|
      ENV[k] = v
    end
  end

  describe "Connecting" do
    it "connects with connection string" do
      c = HoldingsDB.connection(connection_string)
      expect(c.tables).to include(:ht_institutions)
    end

    it 'connects with piecemeal keyword args' do
      c = HoldingsDB.connection(user: user, password: password, database: database, host: host)
      expect(c.tables).to include(:ht_institutions)
    end

    it "connects with ENV connection string" do
      wipe_env
      ENV['DB_CONNECTION_STRING'] = connection_string
      c                           = HoldingsDB.connection
      expect(c.tables).to include(:ht_institutions)
    end

    it "connects with ENV settings" do
      wipe_env
      set_env
      c = HoldingsDB.connection
      expect(c.tables).to include(:ht_institutions)
    end

    it "fails as expected with bad env" do
      wipe_env
      set_env
      ENV['DB_USER'] = "NO_SUCH_USER"
      expect {HoldingsDB.connection}.to raise_error(Sequel::DatabaseConnectionError)
    end

    it "allows override of ENV" do
      wipe_env
      set_env
      ENV['DB_USER'] = "NO_SUCH_USER"
      c = HoldingsDB.connection(user: user)
      expect(c.tables).to include(:ht_institutions)
    end
  end

  describe "Data is loaded" do
    it "finds all the tables" do
      expect(connection.tables).to match_array([:ht_collections, :ht_institutions])
    end

    it "finds all the institutions" do
      c = HoldingsDB.connection(user: user, password: password, database: database, host: host)
      expect(c[:ht_institutions].count).to equal(249)
    end
  end
end
