require "workflows/solr_data_source"
require "clusterable/ht_item"

module Workflows
  module CostReport
    class DataSource < Workflows::SolrDataSource
      def dump_records(output_filename)
        with_milemarked_output(output_filename) do |output_record|
          cursorstream do |s|
            s.filters = filters
          end.each do |record|
            output_record.call(record)
          end
        end
      end

      def filters
        ic_rights = Clusterable::HtItem::IC_RIGHTS_CODES.join(" ")
        ["ht_rightscode:(#{ic_rights})"]
      end
    end
  end
end
