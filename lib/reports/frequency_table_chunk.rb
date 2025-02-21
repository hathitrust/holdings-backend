require "frequency_table"
require "clusterable/ht_item"
require "services"
require "milemarker"

# Generates a frequency table given an input file containing
# tabular data from hf:
#    htid bib_num rights_code access bib_fmt description collection_code oclc

module Reports
  class FrequencyTableChunk
    def initialize(ht_item_file, output_file, batch_size: 5000)
      @ht_item_file = ht_item_file
      @output_file = output_file
      @batch_size = batch_size
    end

    def run
      freqtable = FrequencyTable.new
      log = Services.logger
      marker = Milemarker.new(batch_size: batch_size)

      # Services.holdings_db.loggers << Logger.new($stdout);
      log.info("starting freq table generation from #{ht_item_file}")

      File.open(ht_item_file).each_line do |line|
        fields = line.split("\t", -1)
        # ignore things missing collection code?
        next unless fields[6]
        htitem = Clusterable::HtItem.new(
          item_id: fields[0],
          ht_bib_key: fields[1],
          rights: fields[2],
          access: (fields[3] == "1") ? "allow" : "deny",
          bib_fmt: fields[4],
          enum_chron: fields[5],
          collection_code: fields[6],
          ocns: fields[7]
        )
        # ensure ocns are on the same cluster
        # eventually this could probably be removed to improve performance, if
        # we are ensuring cluster_ocns is up-to-date with htitems
        Cluster.cluster_ocns!(htitem.ocns)

        freqtable.add_ht_item(htitem)

        marker.incr
        marker.on_batch { |m| log.info "#{$$}: #{m.batch_line}" }
      end
      log.info "#{$$}: #{marker.final_line}"
      log.info("#{$$}: done w freq table, writing to #{output_file}")

      File.open(output_file, "w") do |fh|
        fh.puts(freqtable.to_json)
      end
    end

    private

    attr_reader :ht_item_file, :output_file, :batch_size
  end
end
