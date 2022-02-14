# frozen_string_literal: true

require "clusterable/ht_item"
require "clustering/cluster_ht_item"

module Loader
  # Constructs batches of HtItems from incoming file data
  class HtItemLoader
    def item_from_line(line)
      fields = line.split("\t")

      Clusterable::HtItem.new(
        item_id: fields[0],
        ocns: fields[7].split(",").map(&:to_i),
        ht_bib_key: fields[3].to_i,
        rights: fields[2],
        access: fields[1],
        bib_fmt: fields[19],
        enum_chron: fields[4],
        collection_code: fields[20]
      )
    end

    def load(batch)
      Clustering::ClusterHtItem.new(batch).cluster
    end
  end
end
