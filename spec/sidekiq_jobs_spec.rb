# frozen_string_literal: true

require "spec_helper"
require "sidekiq_jobs"

class TestCallback
  def on_success(status, options)
    options[:status].ran = true
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

  it "can batch jobs and call callbacks" do
    callback_status = OpenStruct.new

    batch = Sidekiq::Batch.new
    batch.description = "Test Batching"
    batch.on(:success, TestCallback, status: callback_status)
    batch.jobs do
      5.times do |i|
        Jobs::Common.perform_async("FakeJob", {"kw_required" => i}, i)
      end
    end

    # wait for jobs to complete
    batch.status.join

    expect(callback_status.ran).to be true
  end

  xit "failed job goes to retry queue"
  xit "repeatedly failed job reports to slack"
  xit "successful job reports to slack"
end
