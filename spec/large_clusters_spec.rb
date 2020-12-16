# frozen_string_literal: true

require "large_clusters"
require "spec_helper"

RSpec.describe LargeClusters do
  let(:mock_data) { [1_759_445, 8_878_489].to_set }
  let(:large_clusters) { described_class.new(mock_data) }

  describe "#ocns" do
    it "has the list of ocns provided" do
      expect(large_clusters.ocns).to include(1_759_445)
    end
  end

  describe "#load_large_clusters" do
    it "pulls the list of ocns from the ENV file" do
      ENV["LARGE_CLUSTER_OCNS"] = "/tmp/large_cluster_ocns.txt"
      `echo "1001117803" > /tmp/large_cluster_ocns.txt`
      large_clusters = described_class.new
      expect(large_clusters.ocns).to include(1_001_117_803)
    end
  end
end
