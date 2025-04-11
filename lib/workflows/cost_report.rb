require "services"
require "milemarker"
require "clusterable/ht_item"
require "solr/cursorstream"

module Workflows
  module CostReport
    class DataSource
      def dump_records(output)
        core_url = ENV["SOLR_URL"]
        milemarker = Milemarker.new(batch_size: 50000, name: "get solr records")
        milemarker.logger = Services.logger

        File.open(output, "w") do |out|
          Solr::CursorStream.new(url: core_url) do |s|
            s.fields = %w[ht_json id oclc oclc_search title format]
            ic_rights = Clusterable::HtItem::IC_RIGHTS_CODES.join(" ")
            s.filters = ["ht_rightscode:(#{ic_rights})"]
            s.batch_size = 5000
          end.each do |record|
            out.puts record.to_json
            milemarker.increment_and_log_batch_line
          end
        end

        milemarker.log_final_line
      end
    end
  end
end
