require "sidekiq"
require "sidekiq/web"

SESSION_KEY = ".session.key"

if !File.exist?(SESSION_KEY)
  require "securerandom"
  File.open(SESSION_KEY, "w") do |f|
    f.write(SecureRandom.hex(32))
  end
end

Sidekiq.configure_client do |config|
  config.redis = {size: 1}
end

use Rack::Session::Cookie, secret: File.read(SESSION_KEY), same_site: true, max_age: 86400

run Sidekiq::Web
