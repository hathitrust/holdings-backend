# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem "canister"
gem "dotenv"
gem "ettin"
gem "faraday"
gem "milemarker"
gem "mongo"
gem "mongoid"
gem "mysql2"
gem "prometheus-client"
gem "rgl"
gem "sequel"
gem "thor"
gem "zinzout"
gem "puma"
gem "sidekiq"

group :development, :test do
  gem "pry"
  gem "pry-byebug"
end

group :test do
  gem "factory_bot"
  gem "faker"
  gem "rspec"
  gem "simplecov"
  gem "webmock"
end

group :development do
  gem "standard"
  gem "ruby-prof"
  gem "yard"
end
