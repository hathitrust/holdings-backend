# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env")

require "delegate"
require "mysql2"
require "sequel"
require "services"
require "tempfile"

module DataSources
  # Backend for connection to MySQL database for production information about
  # holdings and institutions
  class HoldingsDB < SimpleDelegator

    attr_reader :rawdb
    attr_accessor :connection_string

    def initialize
      @rawdb = self.class.connection
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
      marker = Services.progress_tracker.new(maxlines)
      logger.info("Begin load data infile of #{filepath} into #{tablename}")
      Dir.mktmpdir("#{tablename}_tmp_load", ".") do |dir|
        split_files = split_out_large_file(dir, filepath, maxlines)
        split_files.each do |f|
          load_data_infile(tablename, f)
          if f == split_files.last
            marker.incr File.open(f).count
            logger.info(marker.final_line)
          else
            marker.incr maxlines
            logger.info(marker.batch_line + "; sleeping #{pause_in_seconds}")
            sleep pause_in_seconds
          end
        end
      end
      marker.count
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

    # Connection connects to the database using the connection information
    # specified by Settings.database, which should contain keyword parameters
    # matching those taken by Sequel.connect.
    def self.connection(config = {})
      conn_opts = conn_opts(merge_config(config))

      begin
        Sequel.connect(*conn_opts)
      rescue Sequel::DatabaseConnectionError => e
        Services.logger.error "Error trying to connect"
        raise e
      end
    end

    class << self

      private

      def conn_opts(config)
        local_infile = { config_local_infile: 1 }
        url = config[:url]
        opts = config[:opts]
        if url
          [url, local_infile]
        elsif opts
          [local_infile.merge(opts)]
        else
          []
        end
      end

      # Merge url, opts, or db settings from a hash into our config
      def merge_config(config)
        merged_config = Settings.database.to_hash
        merged_config[:url]  = config[:url]  if config.key?(:url)
        merged_config[:opts] = config[:opts] if config.key?(:opts)

        merged_config
      end
    end

  end
end
