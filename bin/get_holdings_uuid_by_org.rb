# frozen_string_literal: true

require "basic_query_report"

# Get all holdings for a member.
# Usage:
# $ bundle exec ruby get_holdings_uuid_by_org.rb <org_1> (... <org_n>)

query = [
  {"$match": {"holdings.organization": {"$in": ARGV}}},
  {"$unwind": "$holdings"},
  {"$match": {"holdings.organization": {"$in": ARGV}}},
  {"$project": {"holdings.ocn": 1, "holdings.organization": 1, "holdings.uuid": 1}}
]

BasicQueryReport.new.aggregate(query) do |res|
  out_rec = [
    res["holdings"]["ocn"],
    res["holdings"]["organization"],
    res["holdings"]["uuid"]
  ]

  puts out_rec.join("\t")
end
