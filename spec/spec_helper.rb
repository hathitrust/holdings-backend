# frozen_string_literal: true

# set up the test database -- needs to be here before we
# load any other requirements because we may try to connect
# during file load

# protect against wiping out the dev database by accident
raise("DATABASE_ENV must be 'test' -- are you running in the wrong container? (try: docker compose run test)") unless ENV["DATABASE_ENV"] == "test"
system("#{__dir__}/../bin/reset_database.sh --force")

# Note: We don't require our entire project here. This allows us to
# require only those files we need to run our tests.
require "climate_control"
require "factory_bot"
require "fileutils"
require "rspec-sidekiq"
require "sidekiq/batch"
require "simplecov"
require "simplecov-lcov"
require "webmock/rspec"

require "services"
require "settings"
require "fixtures/collections"
require "fixtures/organizations"

require_relative "support/cluster_fixture_data"
require_relative "support/holdings_tables"

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = "coverage/lcov.info"
end
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter
])
Sidekiq.strict_args!
Sidekiq::Testing.inline!

RSpec.configure do |config|
  config.exclude_pattern = "disabled/**/*_spec.rb"

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

  # Ignore tests tagged :slow by default.
  config.filter_run_excluding slow: true

  config.before(:suite) do
    FactoryBot.find_definitions
  end

  config.before(:all) do
    Services.register(:logger) do
      Logger.new("test.log").tap { |l| l.level = Logger::DEBUG }
      # Logger.new(STDERR).tap {|l| l.level = Logger::DEBUG }
    end
    Services.register(:scrub_logger) { Services.logger }
  end

  config.before(:each) do
    # mock HT member data to use in tests. Tests may change this data, so
    # reset it for each test.
    Services.register(:ht_organizations) { mock_organizations }
    Services.register(:ht_collections) { mock_collections }

    # stub external APIs
    Services.register(:pushgateway) { instance_double(Prometheus::Client::Push, add: true) }
    Services.register(:slack) { instance_double(Utils::SlackWriter, write: true) }
    stub_request(:get, "https://www.oclc.org/apps/oclc/wwg").to_return(body: '{ "oclcNumber": "1000000000" }')
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

  config.around(:each, type: "sidekiq_fake") do |example|
    Sidekiq::Testing.fake! do
      example.run
    end
  end

  config.around(:each) do |example|
    Dir.mktmpdir("holdings-testing") do |tmpdir|
      ClimateControl.modify(TEST_TMP: tmpdir) do
        Settings.reload!
        FileUtils.touch(Settings.rclone_config_path)
        example.run
      end
    end
  end
end

# Persists each element in an array of clusterables, building
# clusters when needed.
#
# DRY for the many times the tests need to do something like:
# Clustering::ClusterXYZ.new(xyz).cluster
def load_test_data(*clusterables)
  clusterables.each do |clusterable|
    case clusterable
    when Clusterable::HtItem
      insert_htitem(clusterable)
      Clustering::ClusterHtItem.new(clusterable).cluster
    when Clusterable::OCNResolution
      Clustering::ClusterOCNResolution.new(clusterable).cluster
    when Clusterable::Holding
      # no need to do ClusterHolding at the current time
      clusterable.save
    else
      raise "Can't persist #{clusterable}"
    end
  end
end

def fixture(filename)
  File.join(__dir__, "fixtures", filename)
end

def cluster_count(field)
  Cluster.each.map { |c| c.public_send(field).count }.reduce(0, :+)
end

def Settings.reload!
  merge!(Ettin.for(Ettin.settings_files("config", environment)))
end
