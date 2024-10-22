# frozen_string_literal: true

require "ettin"
require "fileutils"

def determine_environment
  if ENV["ENVIRONMENT"]
    ENV["ENVIRONMENT"]
  elsif File.basename($PROGRAM_NAME) == "rspec"
    "test"
  else
    "development"
  end
end

environment = determine_environment
Settings = Ettin.for(Ettin.settings_files("config", environment))
Settings.environment = environment
