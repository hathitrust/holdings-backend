# frozen_string_literal: true

require "services"
require "settings"
require "loaded_file"
require "file_loader"
require "ht_item_loader"

# Responsible for scrubbing and loading a single member-submitted holdings
# file, where one line represents one Holding.
#
# Usage:
#   HoldingsFile.new("/path/to/file").scrub
#   HoldingsFile.new("/path/to/file").load
class HoldingsFile
  attr_reader :filename, :produced, :loaded

  def initialize(filename, logger = Services.logger)
    @filename = filename
    @logger = logger
  end

  def load(loader: FileLoader.new(batch_loader: HtItemLoader.new))
    begin
      logger.info("Started loading #{filename}")
      loader.load(filename)
      @loaded = Time.now
      mark_loaded
      logger.info("Finished loading file #{filename}")
    rescue StandardError => e
      logger.error("Failed loading #{filename}: #{e}, not trying any more")
      nil
    end
  end

  def produced
    Date.parse('1970-01-01')
  end

  def source
    "invalid"
  end

  def type
    "holdings"
  end

  private

  attr_reader :logger

  def mark_loaded
    LoadedFile.from_object(self).save
  end

  def filename_for(date)
    # The update hathifile produced on a given date is named for the previous day
    Pathname.new(Settings.hathifile_path) + "hathi_upd_#{(date - 1).strftime("%Y%m%d")}.txt.gz"
  end

end
