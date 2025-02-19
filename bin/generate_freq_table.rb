require "frequency_table"
require "clusterable/ht_item"
require "services"
require "milemarker"

f = FrequencyTable.new
log = Services.logger
marker = Milemarker.new(batch_size: 5000)

#Services.holdings_db.loggers << Logger.new($stdout);
log.info("#{$$}: starting freq table")
filename = ARGV[0]
fh = File.open(filename,"r")

ARGF.each_line do |line|
  fields = line.split("\t",-1)
  # ignore things missing collection code?
  next unless fields[6]
  h = Clusterable::HtItem.new(
    item_id: fields[0],
    ht_bib_key: fields[1],
    rights: fields[2],
    access: fields[3] == "1" ? "allow" : "deny",
    bib_fmt: fields[4],
    enum_chron: fields[5],
    collection_code: fields[6],
    ocns: fields[7]
  )
  # ensure ocns are on the same cluster
  Cluster.cluster_ocns!(h.ocns)

  f.add_ht_item(h)

  marker.incr
  marker.on_batch { |m| log.info "#{$$}: #{m.batch_line}" }
end
log.info "#{$$}: #{marker.final_line}"
log.info("#{$$}: done w freq table, writing to #{filename}.freq")


out = File.open("#{filename}.freq","w")
out.puts(f.to_json)
