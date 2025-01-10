# frozen_string_literal: true

# Note: We don't require our entire project here. This allows us to
# require only those files we need to run our tests.
ENV["DATABASE_ENV"] = "test"

require "factory_bot"
require "simplecov"
require "simplecov-lcov"
require "webmock/rspec"
require "fixtures/organizations"
require "fixtures/collections"
require "pry"
require "settings"
require "services"
require "sidekiq/batch"
require "rspec-sidekiq"
require "fileutils"
require_relative "support/cluster_ocn_table"

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
    # mock HT member data to use in tests
    Services.register(:ht_organizations) { mock_organizations }
    Services.register(:ht_collections) { mock_collections }
    Services.register(:logger) do
      Logger.new("test.log").tap { |l| l.level = Logger::DEBUG }
      # Logger.new(STDERR).tap {|l| l.level = Logger::DEBUG }
    end
    Services.register(:scrub_logger) { Services.logger }
  end

  config.before(:each) do
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
      ENV["TEST_TMP"] = tmpdir
      Settings.reload!
      FileUtils.touch(Settings.rclone_config_path)
      example.run
      ENV.delete("TEST_TMP")
    end
  end
end

# Clusters and saves each element in an array of clusterables
# DRY for the many times the tests need to do something like:
# Clustering::ClusterXYZ.new(xyz).cluster.tap(&:save)
def cluster_tap_save(*clusterables)
  clusterables.each do |clusterable|
    case clusterable
    when Clusterable::Holding
      Clustering::ClusterHolding
    when Clusterable::HtItem
      Clustering::ClusterHtItem
    when Clusterable::Commitment
      Clustering::ClusterCommitment
    when Clusterable::OCNResolution
      Clustering::ClusterOCNResolution
    end.new(clusterable).cluster.tap(&:save)
  end
end

def fixture(filename)
  File.join(__dir__, "fixtures", filename)
end

def cluster_count(field)
  Cluster.all.map { |c| c.public_send(field).count }.reduce(0, :+)
end

def Settings.reload!
  merge!(Ettin.for(Ettin.settings_files("config", environment)))
end
