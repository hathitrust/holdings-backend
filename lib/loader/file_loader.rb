# frozen_string_literal: true

require "services"
require "zinzout"
require "ppnum"

module Loader
  # Loads file of records that have been sorted by OCN
  class FileLoader
    def initialize(batch_loader:, batch_size: 10_000, load_batch_size: 100)
      @logger = Services.logger
      @marker = Services.progress_tracker.call(batch_size: batch_size)
      @batch_size = batch_size
      @batch_loader = batch_loader
      @load_batch_size = load_batch_size
    end

    # Skip the first line of a file if it matches the given regexp
    # @param [#each] filehandle The enumerator (presumably a file handle)
    # @param [Regexp] skip_match The regexp which indicates that the first line should be skipped
    # @return [Iterator] An iterator with the first line possibly skipped
    def skip_matching_header(filehandle, skip_match)
      filehandle.tap do |f|
        next unless skip_match

        nextline = f.next
        unless skip_match.match(nextline)
          f.rewind
        end
      end
    end

    # Load the given file
    # @param [String] filename Name of the file to load
    # @param [IO] filehandle Filehandle; will create a ZinZout.zin from the filename if not given
    # @param [Regexp,String] skip_header_match. Skip the first row if it matches this regexp
    # @return [Integer] Number of records loaded
    def load(filename, filehandle: Zinzout.zin(filename), skip_header_match: nil)
      logger.info "Loading #{filename}, batches of #{ppnum @batch_size}"

      batch_loader.batches_for(
        skip_matching_header(filehandle.enum_for(:each), skip_header_match).lazy
        .map { |line| log_and_parse(line) }
      ).each do |batch|
        batch_loader.load(batch)
        Thread.pass
      end

      logger.info marker.final_line
      marker.count
    end

    def load_deletes(filename, filehandle: Zinzout.zin(filename))
      logger.info "Deleting items from #{filename}, batches of #{ppnum @batch_size}"

      filehandle.lazy
        .map { |line| log_and_parse(line) }
        .each { |item| batch_loader.delete(item) }

      logger.info marker.final_line
    end

    private

    def log_and_parse(line)
      marker.incr.on_batch { |m| logger.info m.batch_line }
      batch_loader.item_from_line(line)
    end

    attr_reader :logger, :marker, :batch_size, :batch_loader
  end
end
