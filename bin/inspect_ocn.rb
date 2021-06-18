# frozen_string_literal: true

# For manual/ocular inspection of a single OCN.
# Takes an OCN and outputs a pretty-printed matching cluster.

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "cluster"
require "services"
require "json"

Services.mongo!

def look_up(ocn)
  cluster = Cluster.find_by(ocns: ocn.to_i)
  if cluster.nil?
    "No cluster found for OCN #{ocn}."
  else
    JSON.pretty_generate(cluster.as_document)
  end
end

if $PROGRAM_NAME == __FILE__
  ocn = ARGV.shift
  puts look_up(ocn)
end
