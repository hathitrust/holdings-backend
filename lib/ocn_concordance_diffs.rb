# frozen_string_literal: true

require "services"
require "settings"
require "loader/loaded_file"
require "loader/file_loader"
require "loader/ocn_resolution_loader"

# Responsible for locating and loading a pair of diffs from an OCN concordance.
# Both files contain OCNResolutions represented as variant, canonical (resolved) pairs
# One file contains OCNResolutions to add, the other contains OCNResolutions to
# delete.
#
# Usage: OCNConcordanceDiffs.new(date).load
class OCNConcordanceDiffs
  attr_reader :filename, :produced, :loaded

  def initialize(date, logger = Services.logger)
    @produced = date
    @filename = filename_for(date)
    @logger = logger
  end

  def load(batch_size: 250_000,
    loader: Loader::FileLoader.new(batch_loader: Loader::OCNResolutionLoader.new,
      batch_size: batch_size))
    logger.info("Started loading #{delete_filename}")
    loader.load_deletes(delete_filename)
    logger.info("Started loading #{add_filename}")
    loader.load(add_filename)
    @loaded = Time.now
    mark_loaded
    logger.info("Finished loading file #{filename}")
  rescue => e
    logger.error("Failed loading #{filename}: #{e}, not trying any more")
    nil
  end

  def source
    "oclc"
  end

  def type
    "concordance"
  end

  private

  attr_reader :logger

  def mark_loaded
    Loader::LoadedFile.from_object(self).save
  end

  def filename_for(date)
    # see date handling from https://github.com/hathitrust/oclc_concordance_validator/pull/5/files
    Pathname.new(Settings.concordance_path) + "diffs/comm_diff_#{date.strftime("%Y-%m-%d")}.txt"
  end

  def add_filename
    filename.sub_ext(".txt.adds")
  end

  def delete_filename
    filename.sub_ext(".txt.deletes")
  end
end
