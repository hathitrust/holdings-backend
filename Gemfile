# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

gem "canister"
gem "dotenv"
gem "ettin"
gem "faraday"
gem "mongo"
gem "mongoid"
gem "mysql2"
gem "prometheus-client"
gem "sequel"
gem "zinzout"

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
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rspec"
  gem "ruby-prof"
  gem "yard"
end
