# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem "base64"
gem "canister"
gem "dotenv"
gem "ettin"
gem "faraday"
gem "push_metrics", git: "https://github.com/hathitrust/push_metrics.git", tag: "v0.9.1"
gem "activerecord"
gem "mysql2"
gem "pry"
gem "prometheus-client"
gem "rgl"
gem "sequel"
gem "thor"
gem "zinzout"
gem "puma"
gem "rack-session"
gem "sidekiq"
gem "sidekiq-batch", git: "https://github.com/breamware/sidekiq-batch"
gem "sqlite3", "~> 1.4"

group :test do
  gem "factory_bot"
  gem "faker"
  gem "rspec"
  gem "rspec-sidekiq"
  gem "simplecov"
  gem "simplecov-lcov"
  gem "webmock"
end

group :development do
  gem "standard"
  gem "ruby-prof"
  gem "debug"
end
