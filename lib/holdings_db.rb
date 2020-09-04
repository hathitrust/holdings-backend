# frozen_string_literal: true

require 'sequel'
require 'mysql2'
require 'dotenv'

Dotenv.load(".env")

class HoldingsDB

  attr_reader :rawdb
  attr_accessor :connection_string

  # #create_connection will take
  #  * a full connection string (passed here OR in the environment
  #    variable MYSQL_CONNECTION_STRING)
  #  * a set of named arguments, drawn from those passed in and the environment
  #
  # Easiest is to pass in a full connection string, but you can set useful defaults
  # in the environment and then pass in only what you want to change (e.g., get a
  # different database by just doing `HoldingDB.connect(database: 'otherDB')`)
  #
  # @example
  # DB = HoldingsDB.connect # accept all from ENV
  # DB = HoldingsDB.connect('mysql2://username:password@host:3435/myDatabase') # full connection string
  # DB = HoldingsDB.connect(user: 'otheruser', password: 'herPassword') # change user
  def self.connection(connection_string = ENV['DB_CONNECTION_STRING'],
                      user: ENV['DB_USER'],
                      password: ENV['DB_PASSWORD'],
                      host: (ENV['DB_HOST'] || 'localhost'),
                      port: ENV['DB_PORT'],
                      database: ENV['DB_DATABASE'],
                      adapter: (ENV['DB_ADAPTER'] || :mysql2)
  )
    begin
      if !connection_string.nil?
        Sequel.connect(connection_string)
      else
        db_args = {
            config_local_infile: true,
            adapter:             adapter,
            user:                user,
            password:            password,
            host:                host,
            database:            database
        }
        if port
          args[:port] = port
        end
        Sequel.connect(**db_args)
      end
    rescue Sequel::DatabaseConnectionError => e
      puts "Error trying to connect"
      raise e
    end


  end

end