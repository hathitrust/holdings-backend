# frozen_string_literal: true

require "dotenv"
Dotenv.load(".env.test")

# Note: We don't require our entire project here. This allows us to
# require only those files we need to run our tests.
require "bundler/setup"

require "simplecov"
SimpleCov.start

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
end
