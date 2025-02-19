# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem "base64"
gem "canister"
gem "dotenv"
gem "ettin"
gem "faraday"
gem "push_metrics", git: "https://github.com/hathitrust/push_metrics.git", branch: "main"
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

group :test do
  gem "factory_bot"
  gem "faker"
  gem "hathifiles_database", git: "https://github.com/hathitrust/hathifiles_database.git", branch: "main"
  gem "rspec"
  gem "rspec-sidekiq"
  gem "simplecov"
  gem "simplecov-lcov"
  gem "webmock"
end

group :development do
  gem "standard"
  gem "ruby-prof"
  gem "yard"
  gem "debug"
  gem "ruby-lsp"
  gem "ruby-lsp-rspec"
end
