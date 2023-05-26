require "cluster"
require "data_sources/large_clusters"
require "json"
require "services"
Services.mongo!

input_ocns = ARGV.any? ? ARGV : DataSources::LargeClusters.new.ocns

# A hopefully onetime fix for large clusters that grew too large for
# their own good. Perhaps rewrite this if we keep needing it.

input_ocns.each_with_index do |ocn, i|
  puts "## OCN #{ocn} (cluster #{i + 1} of #{input_ocns.size})"
  puts Time.new.strftime("%Y-%m-%d %H:%M:%S")

  clu = Cluster.find_by(ocns: ocn.to_i)
  puts "clu.holdings.size #{clu.holdings.size}"
  # org_grp: array of holdings by group:
  # [
  #   [ {allegheney holdings 1}, {allegheney holdings 2}, ...],
  #   [ {amherst holdings 1}, {amherst holdings 2}, ... ],
  #   ...
  # ]
  org_grp = clu.holdings.group_by(&:organization).values
  puts "org_grp.size #{org_grp.size}"

  # org_grp_1st: array of the first holding per group:
  # [
  #   [ {allegheney holdings 1}.],
  #   [ {amherst holdings 1}],
  #   ...
  # ]
  org_grp_1st = org_grp.map(&:first)
  puts "org_grp_1st.size #{org_grp_1st.size}"

  clu.holdings = org_grp_1st
  clu.save
  clu = Cluster.find_by(ocns: ocn.to_i)
  puts "updated clu.holdings.size: #{clu.holdings.size}"
end

# One line inserter for reference, assuming cluster.json is dumped from mongo
# and has its $oids removed:
# Mongoid.default_client[:clusters].insert_one(JSON.parse(File.read("cluster.json")))
