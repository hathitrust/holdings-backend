# frozen_string_literal: true

require "shared_print/update_record"
require "spec_helper"

RSpec.xdescribe SharedPrint::UpdateRecord do
  let(:org) { "umich" }
  let(:ocn) { 5 }
  let(:loc) { "i123" }
  let(:arg) { {organization: org, ocn: ocn, local_id: loc} }

  it "Accepts minimal OK required fields" do
    expect { described_class.new(arg) }.not_to raise_error
  end
  it "Casts non-string field values" do
    rec = described_class.new(arg)
    expect(rec.cast(:ocn, "5")).to be_a Integer
    expect(rec.cast(:committed_date, "2020-01-01")).to be_a DateTime
    expect(rec.cast(:policies, "a,b,c")).to eq ["a", "b", "c"]
    expect(rec.cast(:facsimile, "true")).to be true
    expect(rec.cast(:facsimile, "false")).to be false
  end
  it "Raises ArgumentError if missing any required fields" do
    fields1 = {organization: org, ocn: ocn}
    fields2 = {organization: org, local_id: loc}
    fields3 = {ocn: ocn, local_id: loc}
    expect { described_class.new(fields1) }.to raise_error ArgumentError
    expect { described_class.new(fields2) }.to raise_error ArgumentError
    expect { described_class.new(fields3) }.to raise_error ArgumentError
  end
  it "Raises ArgumentError if unrecognized field" do
    fields = {organization: org, ocn: ocn, local_id: loc, lunch_time: "soon"}
    expect { described_class.new(fields) }.to raise_error ArgumentError
  end
end
