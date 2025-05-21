# frozen_string_literal: true

# You are strongly discouraged from adding to this -- if you do, various
# precomputed expectations about weights and cost reports will no longer be
# true.

def mock_organizations
  mock = lambda do |inst, country, weight, sym, status = true, mapto_inst = inst|
    DataSources::HTOrganization.new(
      mapto_inst_id: mapto_inst,
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
    "stanford" => mock.call("stanford", "us", 1.0, "STF", true, "stanford_mapped"),
    "ualberta" => mock.call("ualberta", "ca", 1.0, "UAB", true, "stanford_mapped"),
    "utexas" => mock.call("utexas", "us", 3.0, "IXA"),
    "hathitrust" => mock.call("hathitrust", "us", 0.0, ""),
    "uct" => mock.call("uct", "za", 0.0, "OI@", false)
  )
end
