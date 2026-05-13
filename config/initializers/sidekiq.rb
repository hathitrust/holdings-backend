require "sidekiq"
require "services"
require "utils/sidekiq_failure_notifier"

# Add anything here you need for sidekiq initialization

if ENV["REDIS_SIDEKIQ_RW_HOST"] && ENV["REDIS_SIDEKIQ_RW_PASSWORD"]
  Services.register(:redis_config) do
    {
      host: ENV["REDIS_SIDEKIQ_RW_HOST"],
      password: ENV["REDIS_SIDEKIQ_RW_PASSWORD"]
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

  config.server_middleware do |chain|
    chain.add Utils::SidekiqFailureNotifier::Middleware
  end

  config.death_handlers << lambda { |job, exception|
    Utils::SlackNotifier.post(
      Utils::SidekiqFailureNotifier.death_message(job, exception),
      url: Utils::SidekiqFailureNotifier.alerts_url
    )
  }
end

Sidekiq.configure_client do |config|
  config.redis = Services.redis_config
end
