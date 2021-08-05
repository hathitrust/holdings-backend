# frozen_string_literal: true

require "services"
require "date"
require "hathifile"
require "loaded_file"

module Loader

  # Usage: HathifileManger.new.try_load
  #
  # Loads incremental daily Hathifiles that have not yet been loaded into the
  # system. Checks if the loading flag is set; if not, attempts to load all files
  # since the last one that was successfully loaded.
  #
  # If a particular file fails loading, will not attempt to load the remaining
  # files. Files should be loaded in the order in which they were produced to
  # ensure the most recent update to a given HtItem is the one represented in the
  # system.
  class HathifileManager

    def initialize(hathifile_factory: ->(date) { Hathifile.new(date) },
      last_loaded: LoadedFile.latest(type: "hathifile").produced,
      loading_flag: Services.loading_flag)
      @hathifile_factory = hathifile_factory
      @loading_flag = loading_flag
      @last_loaded = last_loaded
    end

    def try_load
      return unless any_to_load?

      loading_flag.with_lock do
        load_all_new
      end
    end

    private

    attr_reader :hathifile_factory, :loading_flag, :last_loaded

    def any_to_load?
      if last_loaded == Date.today
        Services.logger.info("Most recent Hathifile is already loaded, not loading anything")
        false
      else
        true
      end
    end

    def load_all_new
      (last_loaded + 1).upto(Date.today).each do |date|
        break unless hathifile_factory.call(date).load
      end
    end
  end
end
