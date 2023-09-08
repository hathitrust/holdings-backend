# frozen_string_literal: true

# For manual/ocular inspection of clusters based on OCN(s).
# Takes 1+ OCN(s) commandline args and outputs pretty-printed array
# of matching clusters.
# Usage:
# $ bundle exec ruby bin/inspect_ocn.rb req:ocn_1 (... opt:ocn_n)

require "cluster"
require "services"
require "json"

def main
  Services.mongo!
  @buffer = []
  @warnings = []

  ARGV.each do |ocn|
    look_up(ocn)
  end
  puts JSON.pretty_generate(@buffer)
  warn @warnings.join("\n")
end

def look_up(ocn)
  cluster = Cluster.find_by(ocns: ocn.to_i)
  if cluster.nil?
    @warnings << "# Warning: No cluster found for OCN #{ocn}."
  else
    @buffer << cluster.as_document
  end
end

main if $PROGRAM_NAME == __FILE__
