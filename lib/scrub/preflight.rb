# frozen_string_literal: true

require "data_sources/directory_locator"
require "scrub/autoscrub"
require "scrub/malformed_file_error"
require "scrub/record_counter"
require "utils/file_transfer"

module Scrub
  # Combines download and autoscrub, either as part of holdings load,
  # and for checking well-formedness of member submitted files.
  # Can clean up after itself by using a temp directory, or by removing downloaded
  # files in the case of error.
  #
  # Operates on a single member submitted file per instance.
  class Preflight
    attr_reader :downloaded_file, :error, :force, :organization, :remote_file, :scrubber

    def initialize(organization:, remote_file:, force: false, local_dir: nil)
      @downloaded_file = nil
      @force = force
      @organization = organization
      @remote_file = remote_file
      @local_dir = local_dir
      @scrubber = nil
    end

    # Returns self on success
    # Raises MalformedFileError if delta between loaded data and this file is too great.
    def run
      Services.logger.info "Preflighting member file at #{remote_file}"
      download
      @scrubber = Scrub::AutoScrub.new(downloaded_file)
      scrubber.run
      record_counter = Scrub::RecordCounter.new(organization, scrubber.item_type)
      unless record_counter.acceptable_diff? || force
        raise MalformedFileError, [
          "Diff too big for #{organization} when scrubbing #{remote_file}.",
          record_counter.message.join("\n"),
          "This file will not be loaded."
        ].join("\n")
        # Run again with --force to load anyways.
      end
      self
    end

    def clean_up!
      if downloaded_file && File.exist?(downloaded_file)
        FileUtils.rm(downloaded_file)
      end
    end

    def download
      remote_path = File.join(remote_dir, remote_file)
      Utils::FileTransfer.new.download(remote_path, local_dir)
      @downloaded_file = File.join(local_dir, File.split(remote_path).last)
    end

    private

    def remote_dir
      DataSources::DirectoryLocator.for(:remote, organization).holdings_current
    end

    def local_dir
      @local_dir ||= DataSources::DirectoryLocator.for(:local, organization).holdings_current
    end
  end
end
