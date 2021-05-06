# frozen_string_literal: true

require "services"
require "settings"
require "loaded_file"
require "file_loader"
require "ht_item_loader"

# Responsible for locating and loading a single Hathifile, a file containing
# HtItems represented as tab-separated values.
#
# Usage: Hathifile.new(date).load
class Hathifile
  attr_reader :filename, :produced, :loaded

  def initialize(date, logger = Services.logger)
    @produced = date
    @filename = filename_for(date)
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

  def source
    "hathitrust"
  end

  def type
    "hathifile"
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
