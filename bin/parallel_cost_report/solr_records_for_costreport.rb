require "solr/cursorstream"
require "faraday"
require "json"
require "milemarker"

core_url = ENV["SOLR_URL"]
milemarker = Milemarker.new(batch_size: 10000, name: "stream results")
milemarker.create_logger!($stderr)

# we want:
# - at least two records
# - disjoint set of oclc_search
# - one is NOT a shadow record

Solr::CursorStream.new(url: core_url) do |s|
  s.fields = %w[ht_json id oclc oclc_search title format]
  s.filters = ["ht_rightscode:(ic op und nobody pd-pvt)"]
  s.batch_size = 5000
end.each do |record|
  puts record.to_json
  milemarker.increment_and_log_batch_line
end

milemarker.log_final_line
