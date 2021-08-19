# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "services"
require "cluster"
require "clusterable/holding"
require "pry"

# Start a pry-shell with Services, Cluster, Holding and Mongo pre-loaded.
# Usage:
# $ bundle exec ruby bin/pry_shell.rb

Services.mongo!

# rubocop:disable Lint/Debugger
binding.pry
puts "Running pry shell."
# rubocop:enable Lint/Debugger
