RSpec.shared_context "with mocked solr response" do
  # Mock response from solr. Each htitem is assumed to be
  # on its own record. This also doesn't account for any concordance info.
  # This isn't the complete response solr actually returns, but it
  # should include everything we use.
  #

  def solr_docs_for(*htitems)
    htitems.group_by(&:ht_bib_key).map do |ht_bib_key, htitems|
      record_ocns = htitems.collect(&:ocns).flatten.uniq.map(&:to_s)

      {
        "id" => ht_bib_key,
        "format" => [(htitems.first.bib_fmt == "SE") ? "Serial" : "Book"],
        "oclc" => record_ocns,
        "oclc_search" => record_ocns,
        "ht_json" => htitems.map do |htitem|
          {
            "htid" => htitem.item_id,
            "rights" => [htitem.rights, nil],
            "enumcron" => htitem.enum_chron,
            "collection_code" => htitem.collection_code.downcase
          }
        end.to_json
      }
    end
  end

  def solr_response_for(*htitems)
    {
      "responseHeader" => {},
      "response" => {
        "numFound" => htitems.count,
        "start" => 0,
        "docs" => solr_docs_for(*htitems)
      }
    }.to_json
  end

  def mock_solr_rights_search(body, filter: /ht_rightscode:.*/)
    mock_solr_search_filtered(body, filter)
  end

  def mock_solr_oclc_search(body, filter: /oclc_search:\([\d ]*\)/)
    mock_solr_search_filtered(body, filter)
  end

  def mock_solr_search_filtered(body, filter)
    stub_request(:get, ->(uri) {
      uri.path == "/solr/catalog/select" &&
      uri.query_values.fetch("fq", nil).match?(filter)
    }).to_return(status: 200,
      body: body,
      headers: {
        "Content-type" => "application/json"
      })
  end

  before(:each) do
    # default filter query for most cases in holdings
    filter_query = "ht_rightscode:(ic%20op%20und%20nobody%20pd-pvt)"

    stub_request(:get, "http://localhost:8983/solr/catalog/select?cursorMark=*&fl=ht_json,id,oclc,oclc_search,title,format&fq=#{filter_query}&q=*:*&rows=5000&sort=id%20asc&wt=json")
      .to_return(status: 200,
        body: File.open(fixture("solr_response.json")),
        headers: {
          "Content-type" => "application/json"
        })
  end

  around(:each) do |example|
    ClimateControl.modify(
      SOLR_URL: "http://localhost:8983/solr/catalog"
    ) do
      example.run
    end
  end
end
