# frozen_string_literal: true

require "spec_helper"
require "loader/shared_print_loader"

RSpec.describe Loader::SharedPrintLoader do
  let(:json) do
    '{"uuid":"e78047da-1193-43c7-aab0-492067d13f9c","organization":"ucsd","ocn":2,
      "local_id":"i6536255x","oclc_sym":"CUS","committed_date":"2019-02-28","retention_date":null,
      "local_bib_id":null,"local_item_id":null,"local_item_location":null,
      "local_shelving_type":null,"policies":[],"facsimile":0,"other_program":null,
      "other_retention_date":null,"deprecation_status":null,"deprecation_date":null}'
  end

  describe "#item_from_line" do
    let(:comm) { described_class.new.item_from_line(json) }

    it { expect(comm).to be_a(Clusterable::Commitment) }
    it { expect(comm.organization).to eq("ucsd") }
    it { expect(comm.ocn).to be(2) }
    it { expect(comm.local_id).to eq("i6536255x") }
    it { expect(comm.oclc_sym).to eq("CUS") }
    it { expect(comm.committed_date).to eq(DateTime.parse("2019-02-28")) }
    it { expect(comm.retention_date).to be_nil }
    it { expect(comm.local_bib_id).to be_nil }
    it { expect(comm.local_item_id).to be_nil }
    it { expect(comm.local_item_location).to be_nil }
    it { expect(comm.local_shelving_type).to be_nil }
    it { expect(comm.policies).to eq([]) }
    it { expect(comm.facsimile).to be(false) }
    it { expect(comm.other_program).to be_nil }
    it { expect(comm.other_retention_date).to be_nil }
    it { expect(comm.deprecation_status).to be_nil }
    it { expect(comm.deprecation_date).to be_nil }
  end
end