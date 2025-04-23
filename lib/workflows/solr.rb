require "milemarker"
require "services"
require "solr/cursorstream"

module Workflows
  module Solr
    # Sets up some defaults for a data source that queries solr in batch and
    # saves records for further processing.
    class DataSource
      # Returns a Solr::CursorStream with defaults for getting records for
      # holdings processing.
      #
      # Can further configure the CursorStream if a block is provided.
      def cursorstream
        core_url = ENV["SOLR_URL"]
        ::Solr::CursorStream.new(url: core_url) do |s|
          s.fields = %w[ht_json id oclc oclc_search title format]
          s.batch_size = Settings.solr_data_source.solr_results_per_query
          yield s if block_given?
        end
      end

      # Opens the given output file and yields a proc which can be called
      # to write a record to the file and to log progress using a Milemarker.
      #
      # The Milemarker's batch size is configured using the
      # solr_data_source.milemarker_batch_size setting.
      def with_milemarked_output(output_filename)
        milemarker_batch_size = Settings.solr_data_source.milemarker_batch_size
        milemarker = Milemarker.new(batch_size: milemarker_batch_size,
          name: "#{self.class}: get solr records")
        milemarker.logger = Services.logger

        File.open(output_filename, "w") do |fh|
          output_record = ->(record) do
            fh.puts(record.to_json)
            milemarker.increment_and_log_batch_line
          end

          yield output_record
        end

        milemarker.log_final_line
      end
    end

    # Fetches holdings for batches of solr records from an input file and hands
    # them off for further analysis.
    #
    # If organization is given, limits holdings loaded to that organization;
    # otherwise, loads all holdings.
    class Analyzer
      # TODO address with organization in solr batch
      def records_from_file(input, organization: nil)
        return to_enum(__method__, input) unless block_given?

        milemarker = Milemarker.new(batch_size: Settings.solr_analyzer.milemarker_batch_size,
          name: "#{self.class}: analyze solr records")
        milemarker.logger = Services.logger

        File.open(input).each_slice(Settings.solr_analyzer.solr_batch_size) do |lines|
          SolrBatch.new(lines, organization: organization).records.each do |record|
            yield record
            milemarker.increment_and_log_batch_line
            Thread.pass
          end
        end

        milemarker.log_final_line
      end
    end
  end
end
