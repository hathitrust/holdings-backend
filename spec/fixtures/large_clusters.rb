# frozen_string_literal: true

def mock_large_clusters
  DataSources::LargeClusters.new(Set.new([1_759_445, 8_878_489, 1_001_117_803, 1_042_124_096]))
end
