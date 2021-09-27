# frozen_string_literal: true

require "services"
require "cluster"
Services.mongo!

Cluster.create_indexes
