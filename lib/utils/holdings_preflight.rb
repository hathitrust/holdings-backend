# frozen_string_literal: true

require "clusterable/holding"
require "utils/file_transfer"

module Utils
  class HoldingsPreflight
    def initialize(file_transfer: Utils::FileTransfer.new)
      @file_transfer = file_transfer
    end

    def format_counts(org)
      rows = Clusterable::Holding.format_counts(org)
      counts = rows.map { |r| {format: r[:mono_multi_serial], count: r[:count]} }
      {counts: counts, total: counts.sum { |r| r[:count] }}
    end

    def dir_counts(remote_dir)
      tsv_files = @file_transfer.lsjson(remote_dir)
        .reject { |f| f["IsDir"] }
        .select { |f| f["Name"].end_with?(".tsv") }
        .sort_by { |f| f["Name"] }
      counts = tsv_files.map do |f|
        count = @file_transfer.cat("#{remote_dir}/#{f["Path"]}", &:count)
        {name: f["Name"], count: count}
      end
      {counts: counts, total: counts.sum { |r| r[:count] }}
    end
  end
end
