# frozen_string_literal: true

require "scrub/ocn_candidate"

RSpec.describe Scrub::OcnCandidate do
  # Not doing the full test suite, as it is already covered by spec/scrub/ocn_spec.rb
  it "validates an easy case" do
    cand = described_class.new("1")
    expect(cand.numeric_part).to eq 1
    expect(cand.valid?).to be true
  end

  it "invalidates an easy case" do
    cand = described_class.new("0")
    expect(cand.numeric_part).to eq 0
    expect(cand.valid?).to be false
  end
end
