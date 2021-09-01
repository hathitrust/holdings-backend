#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints all current members to stdout
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "data_sources/ht_members"
puts DataSources::HTMembers.new.members.keys
