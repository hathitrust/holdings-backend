require "sidekiq"
require "services"

# Add anything here you need for sidekiq initialization

if ENV["REDIS_SIDEKIQ_RW_HOST"] && ENV["REDIS_SIDEKIQ_RW_PASSWORD"]
  Services.register(:redis_config) do
    {
      name: ENV["REDIS_SIDEKIQ_RW_HOST"],
      password: ENV["REDIS_SIDEKIQ_RW_PASSWORD"],
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
