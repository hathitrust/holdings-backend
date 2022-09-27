require "sidekiq"

# Add anything here you need for sidekiq initialization

redis_config = {
  url: "redis://redis"
}

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
