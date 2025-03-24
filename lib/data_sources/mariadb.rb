# frozen_string_literal: true

require "delegate"
require "sequel"
require "services"

module DataSources
  # Backend for connection to MySQL database for production information about
  # holdings and institutions
  class MariaDB < SimpleDelegator
    attr_reader :rawdb

    def initialize(env_key)
      @rawdb = self.class.connection(env_key)
      # Check once every few seconds that we're actually connected and reconnect if necessary
      @rawdb.extension(:connection_validator)
      @rawdb.pool.connection_validation_timeout = 5
      super(@rawdb)
    end

    # Connection connects to the database using the connection information
    # specified by environment variables MARIADB_ENV_KEY_USERNAME, _PASSWORD,
    # _HOST, and _DATABASE.
    def self.connection(env_key)
      Sequel.connect(
        adapter: "trilogy",
        user: ENV["MARIADB_#{env_key}_USERNAME"],
        password: ENV["MARIADB_#{env_key}_PASSWORD"],
        host: ENV["MARIADB_#{env_key}_HOST"],
        database: ENV["MARIADB_#{env_key}_DATABASE"],
        encoding: "utf8mb4"
      )
    rescue Sequel::DatabaseConnectionError => e
      Services.logger.error "Error trying to connect"
      raise e
    end
  end
end
