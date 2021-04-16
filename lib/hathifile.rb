# frozen_string_literal: true

require "services"
require "settings"
require "holdings_file"

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
    HoldingsFile.from_object(self).save
  end

  def filename_for(date)
    Pathname.new(Settings.hathifile_path) + "hathi_upd_#{date.strftime("%Y%m%d")}.txt.gz"
  end

end
