#!/usr/bin/env ruby
# frozen_string_literal: true

require "services"
require "loader/hathifile_manager"

def main
  Services.mongo!
  Loader::HathifileManager.new.try_load
end

main if __FILE__ == $PROGRAM_NAME
