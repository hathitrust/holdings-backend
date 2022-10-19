require "sidekiq"
require "sidekiq/web"
require_relative "../config/initializers/sidekiq"

SESSION_KEY = ".session.key"

if !File.exist?(SESSION_KEY)
  require "securerandom"
  File.open(SESSION_KEY, "w") do |f|
    f.write(SecureRandom.hex(32))
  end
end

Services.redis_config[:size] = 1

use Rack::Session::Cookie, secret: File.read(SESSION_KEY), same_site: true, max_age: 86400

run Sidekiq::Web
