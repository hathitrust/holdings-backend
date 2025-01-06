# frozen_string_literal: true

require "ettin"

environment = ENV["DATABASE_ENV"] || "development"
Settings = Ettin.for(Ettin.settings_files("config", environment))
Settings.environment = environment
