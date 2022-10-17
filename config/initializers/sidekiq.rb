require "sidekiq"
require "services"

# Add anything here you need for sidekiq initialization

if ENV["REDIS_MASTER_SET_NAME"] && ENV["REDIS_HEADLESS_SERVICE"]
  require "resolv"

  # https://github.com/mperham/sidekiq/issues/5194
  redis_config = {
    host: ENV["REDIS_MASTER_SET_NAME"],
    password: ENV["REDIS_PASSWORD"],
    sentinels: Resolv.getaddresses(ENV["REDIS_HEADLESS_SERVICE"]).map do |address|
      {host: address, port: 26379, password: ENV["REDIS_PASSWORD"]}
    end
  }
else
  redis_config = {
    url: Settings.redis_url || "redis://redis"
  }
end

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
