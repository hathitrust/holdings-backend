# frozen_string_literal: true

def mock_organizations
  DataSources::HTOrganizations.new(
    "upenn" => DataSources::HTOrganization.new(inst_id: "upenn", country_code: "us", weight: 1.0),
    "umich" => DataSources::HTOrganization.new(inst_id: "umich", country_code: "us", weight: 1.0),
    "smu" => DataSources::HTOrganization.new(inst_id: "smu", country_code: "us", weight: 1.0),
    "stanford" => DataSources::HTOrganization.new(inst_id: "stanford", country_code: "us",
                                                   weight: 1.0),
    "ualberta" => DataSources::HTOrganization.new(inst_id: "ualberta", country_code: "ca",
                                                   weight: 1.0),
    "utexas" => DataSources::HTOrganization.new(inst_id: "utexas", country_code: "us", weight: 3.0),
    "uct" => DataSources::HTOrganization.new(inst_id: "uct", country_code: "za", weight: 0.0,
                                               status: 0)
  )
end
