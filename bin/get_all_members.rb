#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints all current members to stdout
require "data_sources/ht_organizations"

def main
  puts DataSources::HTOrganizations.new.members.keys
end

main if $PROGRAM_NAME == __FILE__
