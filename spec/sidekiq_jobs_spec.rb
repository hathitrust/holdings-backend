# frozen_string_literal: true

require "spec_helper"
require "sidekiq_jobs"

class TestCallback
  def self.did_run
    @did_run
  end

  def self.set_run(did_run)
    @did_run = did_run
  end

  def on_success(status, options)
    puts "Callback ran: #{status}, #{options}"
    self.class.set_run(true)
    Thread.exit
  end
end

class FakeJob
  def initialize(required, optional = "default", kw_required:, kw_optional: "default")
    @required = required
    @optional = optional
    @kw_required = kw_required
    @kw_optional = kw_optional
  end

  def run
    puts "running FakeJob #{@required}: #{self}"
    {
      required: @required,
      optional: @optional,
      kw_required: @kw_required,
      kw_optional: @kw_optional
    }
  end
end

RSpec.describe Jobs::Common do
  it "can marshal options and positional argumnets" do
    expect(Jobs::Common.new.perform("FakeJob", {"kw_required" => "kw_required",
                                                "kw_optional" => "kw_optional"},
      "required", "optional"))
      .to eq({
        required: "required",
        optional: "optional",
        kw_required: "kw_required",
        kw_optional: "kw_optional"
      })
  end

  it "can handle optional options and positional arguments" do
    expect(Jobs::Common.new.perform("FakeJob", {"kw_required" => "kw_required"}, "required"))
      .to eq({
        required: "required",
        optional: "default",
        kw_required: "kw_required",
        kw_optional: "default"
      })
  end

  xit "can batch jobs and call callbacks" do
    Sidekiq::Testing.disable! do
      TestCallback.set_run(false)

      batch = Sidekiq::Batch.new
      batch.description = "Test Batching"
      batch.on(:success, TestCallback)
      batch.jobs do
        5.times do |i|
          Jobs::Common.perform_async("FakeJob", {"kw_required" => i}, i)
        end
      end

      sidekiq = Thread.new do
        Sidekiq.configure_embed do |config|
          config.logger.level = Logger::DEBUG
          config.queues = %w[critical default low]
          config.concurrency = 1
        end.run
      end

      # wait for jobs to complete and callback to run
      sidekiq.join
      expect(TestCallback.did_run).to be true
    end
  end
end
