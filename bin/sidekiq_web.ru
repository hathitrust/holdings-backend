# This is sidekiq_web.ru
# Run with `bundle exec rackup sidekiq_web.ru` or similar.

require "securerandom"
require "rack/session"
require "sidekiq/web"
require_relative "../config/initializers/sidekiq"

# In a multi-process deployment, all Web UI instances should share
# this secret key so they can all decode the encrypted browser cookies
# and provide a working session.
# Rails does this in /config/initializers/secret_token.rb
secret_key = SecureRandom.hex(32)
use Rack::Session::Cookie, secret: secret_key, same_site: true, max_age: 86400
run Sidekiq::Web
