RSpec.shared_context "with complete data for one cluster" do
  include_context "with tables for holdings"

  # Data from spec/fixtures/cluster_2503661.json, without commitments
  before(:each) do
    Cluster.create(ocns: [2503661])
    insert_htitem(build(:ht_item,
      ocns: [2503661],
      item_id: "nyp.33433082421565",
      ht_bib_key: 8638629,
      rights: "pd",
      bib_fmt: "BK",
      enum_chron: "",
      n_enum: "",
      n_chron: "",
      access: "allow",
      billing_entity: "nypl",
      collection_code: "NYP",
      n_enum_chron: ""))

    holdings = [
      {
        "enum_chron" => "",
        "n_enum" => "",
        "n_chron" => "",
        "ocn" => 2503661,
        "local_id" => "000238264",
        "organization" => "upenn",
        "status" => "CH",
        "condition" => "",
        "date_received" => Date.parse("2018-08-10"),
        "mono_multi_serial" => "spm",
        "issn" => "",
        "gov_doc_flag" => false,
        "uuid" => "bab56a32-cf07-4059-92eb-a213012acf59",
        "n_enum_chron" => ""
      },
      {
        "enum_chron" => "",
        "n_enum" => "",
        "n_chron" => "",
        "ocn" => 2503661,
        "local_id" => "188946",
        "organization" => "umich",
        "status" => "CH",
        "condition" => "",
        "date_received" => Date.parse("2020-05-28"),
        "mono_multi_serial" => "spm",
        "issn" => "",
        "gov_doc_flag" => false,
        "uuid" => "2ab58107-36a8-4ecc-945d-26e3327f9d18",
        "n_enum_chron" => ""
      },
      {
        "enum_chron" => "",
        "n_enum" => "",
        "n_chron" => "",
        "ocn" => 2503661,
        "local_id" => "2503661",
        "organization" => "smu",
        "condition" => "",
        "date_received" => Date.parse("2019-07-19"),
        "mono_multi_serial" => "spm",
        "issn" => "",
        "gov_doc_flag" => false,
        "uuid" => "1a2fc3cb-ffb3-4f7a-b8fc-05b6c3c3b179",
        "n_enum_chron" => ""
      }
    ]

    holdings.each { |h| Clusterable::Holding.table.insert(h) }
  end
end
