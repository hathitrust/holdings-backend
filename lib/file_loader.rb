# frozen_string_literal: true

require "services"
require "zinzout"
require "utils/waypoint"
require "utils/ppnum"

# Loads file of records that have been sorted by OCN
class FileLoader
  def initialize(batch_loader:, batch_size: 10_000)
    @logger = Services.logger
    @waypoint = Utils::Waypoint.new(batch_size)
    @batch_size = batch_size
    @batch_loader = batch_loader
  end

  def load(filename, filehandle: Zinzout.zin(filename))
    logger.info "Loading #{filename}, batches of #{ppnum @batch_size}"

    filehandle.lazy
      .map {|line| log_and_parse(line) }
      .chunk_while {|item1, item2| item1.batch_with?(item2) }
      .each {|batch| batch_loader.load(batch) }

    logger.info waypoint.final_line
  end

  def load_deletes(filename, filehandle: Zinzout.zin(filename))
    logger.info "Deleting items from #{filename}, batches of #{ppnum @batch_size}"

    filehandle.lazy
      .map {|line| log_and_parse(line) }
      .each {|item| batch_loader.delete(item) }

    logger.info waypoint.final_line
  end

  private

  def log_and_parse(line)
    waypoint.incr.on_batch {|wp| logger.info wp.batch_line }
    batch_loader.item_from_line(line)
  end

  attr_reader :logger, :waypoint, :batch_size, :batch_loader

end
