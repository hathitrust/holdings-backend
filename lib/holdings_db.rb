# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

require "delegate"
require "mysql2"
require "sequel"
require "services"
require "tempfile"

# Backend for connection to MySQL database for production information about
# holdings and institutions
class HoldingsDB < SimpleDelegator

  attr_reader :rawdb
  attr_accessor :connection_string

  def initialize(connection_string = ENV["DB_CONNECTION_STRING"], **kwargs)
    @rawdb = self.class.connection(connection_string, **kwargs)
    # Always check that we're actually connected and reconnect if necessary
    @rawdb.extension(:connection_validator)
    @rawdb.pool.connection_validation_timeout = -1
    super(@rawdb)
  end

  # Load the given filepath into the table named.
  # Note that we have to explicitly state that there's isn't an escape character
  # (hence "ESCAPED BY ''") because some fields may end with a backslash -- the default
  # escape character.
  #
  # Under the hood, we split the input file into files with _maxlines_ lines and load them one
  # at a time, pausing _pause_in_seconds_ between loads so mysql replication can keep up
  #
  # @param [Symbol] tablename
  # @param [Pathname, String] filepath Path to the tab-delimited file to load
  # @param [Integer] maxlines How many lines to load at a time. Do not split if maxlines == -1
  # @param [Integer] pause_in_seconds How long to pause between batches of _maxlines_
  # @param [Logger] logger A logger
  # @return [Integer] Total number of lines loaded
  def load_tab_delimited_file(tablename:, filepath:,
    maxlines: 1_000_000, pause_in_seconds: 10,
    logger: Services.logger)
    waypoint = Utils::Waypoint.new(maxlines)
    logger.info("Begin load data infile of #{filepath} into #{tablename}")
    Dir.mktmpdir("#{tablename}_tmp_load", ".") do |dir|
      split_files = split_out_large_file(dir, filepath, maxlines)
      split_files.each do |f|
        load_data_infile(tablename, f)
        if f == split_files.last
          waypoint.incr File.open(f).count
          logger.info(waypoint.final_line)
        else
          waypoint.incr maxlines
          logger.info(waypoint.batch_line + "; sleeping #{pause_in_seconds}")
          sleep pause_in_seconds
        end
      end
    end
    waypoint.count
  end

  def split_out_large_file(dir, filepath, maxlines)
    if maxlines == -1
      [filepath]
    else
      system("cd #{dir} && split #{filepath} -l #{maxlines}")
      Pathname.new(dir).children
    end
  end

  def load_data_infile(table, file)
    @rawdb.run("LOAD DATA LOCAL INFILE '#{file}' INTO TABLE #{table}
                FIELDS TERMINATED BY '\t' ESCAPED BY ''")
  end

  # #connection will take
  #  * a full connection string (passed here OR in the environment
  #    variable MYSQL_CONNECTION_STRING)
  #  * a set of named arguments, drawn from those passed in and the
  #    environment. Arguments are those supported by Sequel.
  #
  # Environment variables are mapped as follows:
  #
  #   user: DB_USER
  #   password: DB_PASSWORD
  #   host: DB_HOST
  #   port: DB_PORT
  #   database: DB_DATABASE
  #   adapter: DB_ADAPTER
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
      Services.logger.error "Error trying to connect"
      raise e
    end
  end

  class << self
    private

    def gather_db_args(args)
      [:user, :password, :host,
       :port, :database, :adapter].each do |db_arg|
         args[db_arg] ||= ENV["DB_#{db_arg.to_s.upcase}"]
       end

      args[:host] ||= "localhost"
      args[:adapter] ||= :mysql2

      args
    end
  end

end
