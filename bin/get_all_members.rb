#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints all current members to stdout
require "data_sources/ht_organizations"
puts DataSources::HTOrganizations.new.members.keys
