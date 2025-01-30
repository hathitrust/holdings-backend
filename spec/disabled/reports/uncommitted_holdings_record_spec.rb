# frozen_string_literal: true

require "reports/uncommitted_holdings_record"
require "spec_helper"

RSpec.xdescribe Reports::UncommittedHoldingsRecord do
  let(:ocn) { 5 }
  let(:org) { "umich" }
  let(:oclc_sym) { "EYM" }
  let(:loc) { "i123" }
  let(:hol) { build(:holding, ocn: ocn, local_id: loc, organization: org) }
  let(:record) { described_class.new(hol) }

  it "attr_reader" do
    expect(record.organization).to eq hol.organization
    expect(record.oclc_sym).to eq oclc_sym
    expect(record.ocn).to eq hol.ocn
    expect(record.local_id).to eq hol.local_id
  end

  it "to_a" do
    expect(record.to_a).to eq [org, oclc_sym, ocn, loc]
  end

  it "to_s" do
    expect(record.to_s).to eq "#{org}\t#{oclc_sym}\t#{ocn}\t#{loc}"
  end
end
