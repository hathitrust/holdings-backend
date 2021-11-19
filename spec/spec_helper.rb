# frozen_string_literal: true

# Note: We don't require our entire project here. This allows us to
# require only those files we need to run our tests.
ENV["MONGOID_ENV"] = "test"

require "factory_bot"
require "simplecov"
require "webmock/rspec"
require "fixtures/organizations"
require "fixtures/collections"
require "fixtures/large_clusters"
require "pry"
require "settings"
require "services"
SimpleCov.start

Mongoid.load!("mongoid.yml", Settings.environment)

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    # This is the behavior most people expect. If you want to use verifying
    # doubles, feel free.
    mocks.verify_partial_doubles = false
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!

  # Warnings showing up in test runs are not all that helpful. We rely
  # on the style linter to flag these.
  config.warnings = false

  config.default_formatter = "doc" if config.files_to_run.one?

  # Factory Bot
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end

  config.before(:all) do
    # Ensure we don't try to use DB for tests by default and that we have
    # mock HT member data to use in tests
    Services.register(:holdings_db) { nil }
    Services.register(:ht_organizations) { mock_organizations }
    Services.register(:ht_collections) { mock_collections }
    Services.register(:large_clusters) { mock_large_clusters }
    Services.register(:logger) do
      Logger.new("test.log").tap {|l| l.level = Logger::DEBUG }
      # Logger.new(STDERR).tap {|l| l.level = Logger::DEBUG }
    end
    Services.register(:scrub_logger) { Services.logger }
  end

  config.before(:each) do
    # stub external APIs
    Services.register(:pushgateway) { instance_double(Prometheus::Client::Push, add: true) }
    Services.register(:slack) { instance_double(Utils::SlackWriter, write: true) }
  end

  config.around(:each, type: "loaded_file") do |example|
    old_logger = Services.logger
    begin
      Services.register(:logger) { logger }
      Loader::LoadedFile.db.transaction(rollback: :always, auto_savepoint: true) do
        example.run
      end
    ensure
      Services.register(:logger) { old_logger }
    end
  end
end
