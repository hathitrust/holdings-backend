RSpec.shared_context "with mocked solr response" do
  # Mock response from solr. Each htitem is assumed to be
  # on its own record. This also doesn't account for any concordance info.
  # This isn't the complete response solr actually returns, but it
  # should include everything we use.

  def solr_response_for(*htitems)
    {
      "responseHeader" => {},
      "response" => {
        "numFound" => htitems.count,
        "start" => 0,
        "docs" => htitems.map do |htitem|
          {
            "id" => htitem.ht_bib_key,
            "format" => (htitem.bib_fmt == "SE") ? "Serial" : "Book",
            "oclc" => htitem.ocns.map(&:to_s),
            "oclc_search" => htitem.ocns.map(&:to_s),
            "ht_json" => [
              "htid" => htitem.item_id,
              "rights" => [htitem.rights, nil],
              "enumcron" => htitem.enum_chron,
              "collection_code" => htitem.collection_code.downcase
            ].to_json
          }
        end
      }
    }.to_json
  end

  def mock_solr_oclc_search(body, filter: /oclc_search:\([\d ]*\)/)
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
    stub_request(:get, "http://localhost:8983/solr/catalog/select?cursorMark=*&fl=ht_json,id,oclc,oclc_search,title,format&fq=ht_rightscode:(ic%20op%20und%20nobody%20pd-pvt)&q=*:*&rows=5000&sort=id%20asc&wt=json")
      .with(
        headers: {
          "Accept" => "*/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "User-Agent" => "Faraday v2.12.2"
        }
      )
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
