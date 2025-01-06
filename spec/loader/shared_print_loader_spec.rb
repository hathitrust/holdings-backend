# frozen_string_literal: true

require "spec_helper"
require "loader/file_loader"
require "loader/shared_print_loader"

RSpec.xdescribe Loader::SharedPrintLoader do
  shared_examples_for "valid commitment with expected fields" do
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
    it { expect(comm.policies).to eq(["blo", "digitizeondemand"]) }
    it { expect(comm.facsimile).to be(false) }
    it { expect(comm.other_program).to be_nil }
    it { expect(comm.other_retention_date).to be_nil }
    it { expect(comm.deprecation_status).to be_nil }
    it { expect(comm.deprecation_date).to be_nil }
    it { expect(comm).to be_valid }
  end

  describe "json loading" do
    let(:json) do
      '{"uuid":"e78047da-1193-43c7-aab0-492067d13f9c","organization":"ucsd","ocn":2,
        "local_id":"i6536255x","oclc_sym":"CUS","committed_date":"2019-02-28","retention_date":null,
        "local_bib_id":null,"local_item_id":null,"local_item_location":null,
        "local_shelving_type":null,"policies":["BLO","DIGITIZEONDEMAND"],"facsimile":0,"other_program":null,
        "other_retention_date":null,"deprecation_status":null,"deprecation_date":null}'
    end

    let(:comm) { described_class.for("whatever.ndj").item_from_line(json) }

    it_behaves_like "valid commitment with expected fields"
  end

  describe "tsv loading" do
    # Utils::TSVReader gets it to this form, so the loader just needs to take
    # it from here

    let(:fields) do
      {uuid: "e78047da-1193-43c7-aab0-492067d13f9c",
       organization: "ucsd",
       ocn: "2",
       local_id: "i6536255x",
       oclc_sym: "CUS",
       committed_date: "2019-02-28",
       retention_date: "",
       local_bib_id: "",
       local_item_id: "",
       local_item_location: "",
       local_shelving_type: "",
       policies: "BLO,DIGITIZEONDEMAND",
       facsimile: "0",
       other_program: "",
       other_retention_date: "",
       deprecation_status: "",
       deprecation_date: ""}
    end

    let(:comm) { described_class.for("whatever.tsv").item_from_line(fields) }

    it_behaves_like "valid commitment with expected fields"
  end

  describe "when saving policies to db" do
    it "saves as an array" do
      # Setup, load commitments from fixture
      Cluster.collection.find.delete_many
      fixt = fixture "sp_commitment_policies.tsv"
      Loader::FileLoader.new(batch_loader: described_class.for(fixt))
        .load(fixt, filehandle: described_class.filehandle_for(fixt))
      # Get policies on all loaded commitments
      all_policies = Cluster.each.map do |cluster|
        cluster.commitments.map(&:policies).flatten
      end # -> e.g. [["blo", "digitizeondemand"], ["non-repro", "blo"], []]
      # Check that the loaded policies were saved as arrays
      expect(all_policies).to all be_a Array
    end
  end
end
