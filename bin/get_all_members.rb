#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints all current members to stdout
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require "ht_members"
puts HTMembers.new.members.keys
