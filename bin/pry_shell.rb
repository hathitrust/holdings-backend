# frozen_string_literal: true

require "services"
require "cluster"
require "clusterable/holding"
require "pry"

# Start a pry-shell with Services, Cluster, Holding and Mongo pre-loaded.
# Usage:
# $ bundle exec ruby bin/pry_shell.rb

Services.mongo!

binding.pry
puts "Running pry shell."
