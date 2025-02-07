# frozen_string_literal: true

require "clustering/cluster_holding"
require "utils/file_transfer"

module Loader
  # Constructs batches of Holdings from incoming file data
  class HoldingLoader
    def self.for(filename)
      if filename.end_with?(".tsv")
        HoldingLoaderTSV.new
      elsif filename.end_with?(".ndj")
        HoldingLoaderNDJ.new
      else
        raise "given an invalid file extension"
      end
    end

    def initialize
      @organization = nil
      @current_date = nil
    end

    def item_from_line(_line)
      raise "override me"
    end

    def load(batch)
      Clusterable::Holding.batch_add(batch)
      # Clustering::ClusterHolding.new(batch).cluster
    end
  end

  ## Subclass that only overrides item_from_line
  class HoldingLoaderTSV < HoldingLoader
    def item_from_line(line)
      Clusterable::Holding.new_from_holding_file_line(line).tap do |h|
        @organization ||= h.organization
        @current_date ||= h.date_received
      end
    end
  end

  ## Subclass that only overrides item_from_line
  class HoldingLoaderNDJ < HoldingLoader
    def item_from_line(line)
      Thread.pass # for sidekiq
      Clusterable::Holding.new_from_scrubbed_file_line(line).tap do |h|
        @organization ||= h.organization
        @current_date ||= h.date_received
      end
    end
  end

  class HoldingLoader::Cleanup
    def on_success(_status, options)
      Services.logger.info "removing chunks from #{options["tmp_chunk_dir"]}"
      FileUtils.rm_rf(options["tmp_chunk_dir"])
      Services.logger.info "uploading scrub log #{options["scrub_log"]} " \
                           "to remote dir #{options["remote_dir"]}"
      Utils::FileTransfer.new.upload(
        options["scrub_log"],
        options["remote_dir"]
      )
      Services.logger.info "moving loaded file to scrubber.member_loaded"
      FileUtils.mv(options["loaded_file"], options["loaded_dir"])
      Services.logger.info "cleanup done"
    end
  end
end
