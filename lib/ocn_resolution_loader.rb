# frozen_string_literal: true

require "ocn_resolution"
require "cluster_ocn_resolution"

# Constructs batches of HtItems from incoming file data
class OCNResolutionLoader
  def item_from_line(line)
    (deprecated, resolved) = line.split.map(&:to_i)
    OCNResolution.new(deprecated: deprecated, resolved: resolved)
  end

  def load(batch)
    ClusterOCNResolution.new(batch).cluster
  end
end
