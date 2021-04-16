# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), ".."))
require "services"
require "cluster"
Services.mongo!

Cluster.create_indexes
