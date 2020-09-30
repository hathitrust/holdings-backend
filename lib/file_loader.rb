# frozen_string_literal: true

require "zinzout"
require "utils/waypoint"
require "utils/ppnum"

# Loads file of records that have been sorted by OCN
class FileLoader
  def initialize(batch_size: 10_000, batch_loader:)
    @logger = Services.logger
    @waypoint = Utils::Waypoint.new(batch_size)
    @batch_size = batch_size
    @batch_loader = batch_loader
  end

  def load(filename, filehandle: Zinzout.zin(filename))
    logger.info "Loading #{filename}, batches of #{ppnum @batch_size}"

    last_item = nil
    batch = []

    filehandle.each do |line|
      waypoint.incr
      item = batch_loader.item_from_line(line)
      if last_item && !item.batch_with?(last_item)
        batch_loader.load(batch)
        batch = []
      end

      batch << item
      last_item = item

      waypoint.on_batch {|wp| logger.info wp.batch_line }
    end

    batch_loader.load(batch)
    logger.info waypoint.final_line
  end

  private

  attr_reader :logger, :waypoint, :batch_size, :batch_loader

end
