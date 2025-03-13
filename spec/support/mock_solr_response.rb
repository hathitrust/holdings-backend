RSpec.shared_context "with mocked solr response" do
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
        body: File.read(fixture("solr_response.json")),
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
