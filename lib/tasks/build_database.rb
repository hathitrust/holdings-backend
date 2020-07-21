# frozen_string_literal: true

require "mongoid"

Mongoid.load!("mongoid.yml", :test)

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), ".."))
require "cluster"
Cluster.create_indexes
