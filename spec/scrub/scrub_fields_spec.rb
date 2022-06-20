# frozen_string_literal: true

require "scrub/scrub_fields"
require "services"

RSpec.describe Scrub::ScrubFields do
  let(:sf) { described_class.new }

  it "parses enumchrons" do
    # enum_chron_spec.rb has its own tests,
    # so let's not go into detail here
    expect(sf.enumchron("vol 1, 1999")).to eq(["vol:1", "1999"])
  end
end
