# frozen_string_literal: true

# To please rubocop.
def neu(inst, country, weight, sym, status = 1)
  DataSources::HTOrganization.new(
    inst_id:      inst,
    country_code: country,
    weight:       weight,
    oclc_sym:     sym,
    status:       status
  )
end

def mock_organizations
  DataSources::HTOrganizations.new(
    "upenn"      => neu("upenn", "us", 1.0, "PAU"),
    "umich"      => neu("umich", "us", 1.0, "EYM"),
    "smu"        => neu("smu", "us", 1.0, "ISM"),
    "stanford"   => neu("stanford", "us", 1.0, "STF"),
    "ualberta"   => neu("ualberta", "ca", 1.0, "UAB"),
    "utexas"     => neu("utexas", "us", 3.0, "IXA"),
    "hathitrust" => neu("hathitrust", "us", 0.0, ""),
    "uct"        => neu("uct", "za", 0.0, "OI@", 0)
  )
end
