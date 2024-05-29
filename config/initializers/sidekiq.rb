require "sidekiq"
require "services"

# Add anything here you need for sidekiq initialization

if ENV["REDIS_MASTER_SET_NAME"] && ENV["REDIS_HEADLESS_SERVICE"]
  require "resolv"

  Services.register(:redis_config) do
    # https://github.com/mperham/sidekiq/issues/5194
    {
      name: ENV["REDIS_MASTER_SET_NAME"],
      password: ENV["REDIS_PASSWORD"],
      sentinel_password: ENV["REDIS_PASSWORD"],
      sentinels: Resolv.getaddresses(ENV["REDIS_HEADLESS_SERVICE"]).map do |address|
        {host: address, port: 26379}
      end
    }
  end
else
  Services.register(:redis_config) do
    {
      url: Settings.redis_url || "redis://redis"
    }
  end
end

Sidekiq.configure_server do |config|
  config.redis = Services.redis_config
end

Sidekiq.configure_client do |config|
  config.redis = Services.redis_config
end
