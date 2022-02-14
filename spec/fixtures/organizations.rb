# frozen_string_literal: true

def mock_organizations
  mock = lambda do |inst, country, weight, sym, status = 1|
    DataSources::HTOrganization.new(
      inst_id: inst,
      country_code: country,
      weight: weight,
      oclc_sym: sym,
      status: status
    )
  end

  DataSources::HTOrganizations.new(
    "upenn" => mock.call("upenn", "us", 1.0, "PAU"),
    "umich" => mock.call("umich", "us", 1.0, "EYM"),
    "smu" => mock.call("smu", "us", 1.0, "ISM"),
    "stanford" => mock.call("stanford", "us", 1.0, "STF"),
    "ualberta" => mock.call("ualberta", "ca", 1.0, "UAB"),
    "utexas" => mock.call("utexas", "us", 3.0, "IXA"),
    "hathitrust" => mock.call("hathitrust", "us", 0.0, ""),
    "uct" => mock.call("uct", "za", 0.0, "OI@", 0)
  )
end
