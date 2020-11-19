# frozen_string_literal: true

def mock_members
  HTMembers.new(
    "upenn" => HTMember.new(inst_id: "upenn", country_code: "us", weight: 1.0),
    "umich" => HTMember.new(inst_id: "umich", country_code: "us", weight: 1.0),
    "smu" => HTMember.new(inst_id: "smu", country_code: "us", weight: 1.0),
    "stanford" => HTMember.new(inst_id: "stanford", country_code: "us", weight: 1.0),
    "ualberta" => HTMember.new(inst_id: "ualberta", country_code: "ca", weight: 1.0),
    "utexas" => HTMember.new(inst_id: "utexas", country_code: "us", weight: 3.0)
  )
end
