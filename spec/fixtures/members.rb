# frozen_string_literal: true

def mock_members
  DataSources::HTMembers.new(
    "upenn" => DataSources::HTMember.new(inst_id: "upenn", country_code: "us", weight: 1.0),
    "umich" => DataSources::HTMember.new(inst_id: "umich", country_code: "us", weight: 1.0),
    "smu" => DataSources::HTMember.new(inst_id: "smu", country_code: "us", weight: 1.0),
    "stanford" => DataSources::HTMember.new(inst_id: "stanford", country_code: "us", weight: 1.0),
    "ualberta" => DataSources::HTMember.new(inst_id: "ualberta", country_code: "ca", weight: 1.0),
    "utexas" => DataSources::HTMember.new(inst_id: "utexas", country_code: "us", weight: 3.0)
  )
end
