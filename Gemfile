# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

gem "canister"
gem "mongo"
gem "mongoid"

group :development, :test do
  gem "pry"
end

group :test do
  gem "rspec"
  gem "simplecov"
end

group :development do
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rspec"
  gem "yard"
end
