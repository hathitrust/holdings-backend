# frozen_string_literal: true

require "spec_helper"

require "deletion/cluster_holdings_deleter"

RSpec.describe ClusterHoldingsDeleter do

  it "accepts a cluster as a parameter"
  it "accepts a list of HoldingsDeletionCriteria"
  it "when given a single criteria, removes a holding matching it"
  it "when given multiple criteria, remove all holdings matching any"
  it "when given multiple criteria, keeps holdings that do not match any"

end
