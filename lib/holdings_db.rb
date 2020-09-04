# frozen_string_literal: true

require "sequel"
require "mysql2"
require "dotenv"

Dotenv.load(".env")

# Backend for connection to MySQL database for production information about
# holdings and institutions
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
  # # Accept all from env
  # DB = HoldingsDB.connect
  # # Full connection string
  # DB = HoldingsDB.connect('mysql2://username:password@host:3435/myDatabase')
  # DB = HoldingsDB.connect(user: 'otheruser', password: 'herPassword') # change user
  def self.connection(connection_string = ENV["DB_CONNECTION_STRING"],
    **kwargs)
    begin
      if !connection_string.nil?
        Sequel.connect(connection_string)
      else
        db_args = gather_db_args(kwargs).merge(
          config_local_infile: true
        )
        Sequel.connect(**db_args)
      end
    rescue Sequel::DatabaseConnectionError => e
      puts "Error trying to connect"
      raise e
    end
  end

  class << self
    private

    def gather_db_args(args)
      [:user, :password, :host,
       :port, :database, :adapter].each do |db_arg|
         args[db_arg] ||= ENV["DB_" + db_arg.to_s.upcase]
       end

      args[:host] ||= "localhost"
      args[:adapter] ||= :mysql2

      args
    end
  end

end
