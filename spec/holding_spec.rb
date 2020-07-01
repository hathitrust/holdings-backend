# frozen_string_literal: true

require "holding"
require "cluster"
RSpec.describe Holding do
  let(:c) { create(:cluster) }
  let(:h) { build(:holding) }
  let(:h2) { h.clone }

  it "does not have a parent" do
    expect(build(:holding)._parent).to be_nil
  end

  it "has a parent" do
    c.holdings << build(:holding)
    expect(c.holdings.first._parent).to be(c)
  end

  describe "#==" do
    it "== is true if all fields match except date_received" do
      h2.date_received = Date.yesterday
      expect(h == h2).to be(true)
    end

    it "== is true if all fields match including date_received" do
      expect(h == h2).to be(true)
    end
  end

  describe "#same_as?" do
    let(:h2) { h.clone }

    it "same_as is true if all fields match" do
      expect(h.same_as?(h2)).to be(true)
    end

    it "same_as is not true if date_received does not match" do
      h2.date_received = Date.yesterday
      expect(h.same_as?(h2)).to be(false)
    end
  end
end
