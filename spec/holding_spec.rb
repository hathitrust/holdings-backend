# frozen_string_literal: true

require "holding"
require "cluster"
RSpec.describe Holding do
  let(:c) { create(:cluster) }

  it "does not have a parent" do
    expect(build(:holding)._parent).to be_nil
  end

  it "has a parent" do
    c.holdings << build(:holding)
    expect(c.holdings.first._parent).to be(c)
  end
end
