# frozen_string_literal: true

require "services"
require "zinzout"
require "utils/ppnum"

module Loader
  # Loads file of records that have been sorted by OCN
  class FileLoader
    def initialize(batch_loader:, batch_size: 10_000)
      @logger = Services.logger
      @marker = Services.progress_tracker.new(batch_size)
      @batch_size = batch_size
      @batch_loader = batch_loader
    end

    # Skip the first line of a file if it matches the given regexp
    # @param [#each] filehandle The enumerator (presumably a file handle)
    # @param [Regexp] skip_match The regexp which indicates that the first line should be skipped
    # @return [Iterator] An iterator with the first line possibly skipped
    def skip_matching_header(filehandle, skip_match)
      return filehandle unless skip_match

      iter = filehandle.enum_for(:each)
      nextline = iter.next
      unless skip_match.match(nextline)
        iter.rewind
      end
      iter
    end

    # Load the given file
    # @param [String] filename Name of the file to load
    # @param [IO] filehandle Filehandle; will create a ZinZout.zin from the filename if not given
    # @param [Regexp,String] skip_header_match. Skip the first row if it matches this regexp
    # @return [Integer] Number of records loaded
    def load(filename, filehandle: Zinzout.zin(filename), skip_header_match: nil)
      logger.info "Loading #{filename}, batches of #{ppnum @batch_size}"
      skip_matching_header(filehandle, skip_header_match).each.lazy
        .map { |line| log_and_parse(line) }
        .chunk_while { |item1, item2| item1.batch_with?(item2) }
        .each { |batch| batch_loader.load(batch) }

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
