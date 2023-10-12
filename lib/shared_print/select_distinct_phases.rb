# frozen_string_literal: true

require "basic_query_report"

# Aggregate query to get all committed_date from db.
query = [
  {"$match": {"commitments.0": {"$exists": 1}}},
  {"$unwind": "$commitments"},
  {"$project": {commitments: 1}},
  {"$group": {_id: {date: "$commitments.committed_date"}}}
]

BasicQueryReport.new.aggregate(query) do |res|
  puts res["_id"]["date"]
end

# 2023-01-31 00:00:00 UTC
# 2022-01-01 00:00:00 UTC
# 2021-01-01 05:00:00 UTC
# 2017-09-30 04:00:00 UTC
# 2019-02-28 05:00:00 UTC
# 1970-01-01 00:00:01 UTC
