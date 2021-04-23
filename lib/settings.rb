# frozen_string_literal: true

require "ettin"

environment = ENV["MONGOID_ENV"] || "development"
Settings = Ettin.for(Ettin.settings_files("config", environment))
Settings.environment = environment
