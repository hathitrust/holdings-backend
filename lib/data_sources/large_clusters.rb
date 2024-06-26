# frozen_string_literal: true

require "services"

module DataSources
  # List of ocns for clusters too large to be stored with all holdings records
  class LargeClusters
    attr_accessor :ocns

    def initialize(ocns = load_large_clusters)
      @ocns = ocns
    end

    def load_large_clusters
      ocns = Set.new
      Services.logger.info("Loading large clusters file #{@filename}")
      unless File.exist? Settings.large_cluster_ocns
        Services.logger.warn("No large clusters file found.")
        return ocns
      end
      File.open(Settings.large_cluster_ocns).each_line do |line|
        ocns.add(line.to_i)
      end
      Services.logger.info("Loaded large clusters file, #{ocns.count} ocns loaded")
      ocns
    end
  end
end
