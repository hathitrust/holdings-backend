# frozen_string_literal: true

# Note: We don't require our entire project here. This allows us to
# require only those files we need to run our tests.
require "bundler/setup"

require "factory_bot"
require "simplecov"
require "mongoid"
SimpleCov.start

Mongoid.load!("mongoid.yml", :test)

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
    Services.register(:ht_members) do
      HTMembers.new(
        "carleton" => HTMember.new(inst_id: "carleton", country_code: "us", weight: 1.0),
        "umich" => HTMember.new(inst_id: "umich", country_code: "us", weight: 1.0),
        "smu" => HTMember.new(inst_id: "smu", country_code: "us", weight: 1.0),
        "stanford" => HTMember.new(inst_id: "stanford", country_code: "us", weight: 1.0),
        "ualberta" => HTMember.new(inst_id: "ualberta", country_code: "ca", weight: 1.0),
        "utexas" => HTMember.new(inst_id: "utexas", country_code: "us", weight: 3.0)
      )
    end
  end
end
