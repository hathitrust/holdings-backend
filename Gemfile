# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

gem "mongo"

group :development, :test do
end

group :test do
  gem "coveralls", require: false
  gem "rspec"
end

group :development do
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rspec"
  gem "yard"
end

