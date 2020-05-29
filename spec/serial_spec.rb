# frozen_string_literal: true

require "serial"
require "cluster"
RSpec.describe Serial do
  let(:c) { create(:cluster) }

  it "does not have a parent" do
    expect(build(:serial)._parent).to be_nil
  end

  it "has a parent" do
    c.serials << build(:serial)
    expect(c.serials.first._parent).to be(c)
  end
end
