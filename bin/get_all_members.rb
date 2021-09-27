#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints all current members to stdout
require "data_sources/ht_members"
puts DataSources::HTMembers.new.members.keys
