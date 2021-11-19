# frozen_string_literal: true

require "utils/push_metrics_waypoint"
require "utils/waypoint"
require "prometheus/client/push"

RSpec.describe Utils::PushMetricsWaypoint do
  let(:batch_size) { rand(100) }
  let(:seconds_so_far) { rand(100) }
  let(:records_so_far) { rand(100) }
  let(:success_interval) { 24*60*60 * rand(7) }

  let(:waypoint) do
    instance_double(Utils::Waypoint,
                    finalize: true,
                    total_seconds_so_far: seconds_so_far,
                    count: records_so_far).tap do |d|
                      allow(d).to receive(:on_batch).and_yield(d)
                    end
  end

  let(:pushgateway) { instance_double(Prometheus::Client::Push, add: true) }
  let(:registry) { instance_double(Prometheus::Client::Registry) }
  let(:metrics) do
    {
      duration:          instance_double(Prometheus::Client::Gauge, set: true),
      last_success:      instance_double(Prometheus::Client::Gauge, set: true),
      records_processed: instance_double(Prometheus::Client::Gauge, set: true),
      success_interval:  instance_double(Prometheus::Client::Gauge, set: true)
    }
  end

  let(:params) do
    {
      waypoint:    waypoint,
      registry:    registry,
      metrics:     metrics,
      pushgateway: pushgateway
    }
  end

  let(:pm_waypoint) do
    described_class.new(batch_size, params)
  end

  describe "#initialize" do
    it "can be constructed" do
      expect(pm_waypoint).not_to be(nil)
    end

    it "sets initial values for duration and records processed" do
      expect(metrics[:duration]).to receive(:set).with(seconds_so_far)
      expect(metrics[:records_processed]).to receive(:set).with(records_so_far)

      pm_waypoint
    end

    it "doesn't set last success" do
      expect(metrics[:last_success]).not_to receive(:set)

      pm_waypoint
    end

    it "by default doesn't set success interval" do
      expect(metrics[:success_interval]).not_to receive(:set)

      pm_waypoint
    end

    it "sets success interval metric with constructor param" do
      expect(metrics[:success_interval]).to receive(:set).with(success_interval)

      described_class.new(batch_size, params.merge({ success_interval: success_interval }))
    end

    it "pushes initial metrics to pushgateway" do
      expect(pushgateway).to receive(:add).with(registry)

      pm_waypoint
    end
  end

  describe "#incr" do
    it "delegates to waypoint" do
      expect(waypoint).to receive(:incr)
      pm_waypoint.incr
    end
  end

  describe "#finalize" do
    it "delegates to waypoint" do
      expect(waypoint).to receive(:finalize)

      pm_waypoint.finalize
    end

    it "updates the metrics" do
      expect(metrics[:duration]).to receive(:set).with(seconds_so_far)
      expect(metrics[:records_processed]).to receive(:set).with(records_so_far)
      expect(metrics[:last_success]).to receive(:set).with(Time.now.to_i)

      pm_waypoint.finalize
    end

    it "pushes metrics to pushgateway" do
      expect(pushgateway).to receive(:add).with(registry)

      pm_waypoint.finalize
    end
  end

  describe "#on_batch" do
    it "delegates to waypoint" do
      expect(waypoint).to receive(:on_batch)

      pm_waypoint.on_batch {}
    end

    it "updates the metrics" do
      expect(metrics[:duration]).to receive(:set).with(seconds_so_far)
      expect(metrics[:records_processed]).to receive(:set).with(records_so_far)

      pm_waypoint.on_batch {}
    end

    it "pushes metrics to pushgateway" do
      expect(pushgateway).to receive(:add).with(registry)

      pm_waypoint.on_batch {}
    end

    it "doesn't overwrite last success metric" do
      expect(metrics[:last_success]).not_to receive(:set)

      pm_waypoint.on_batch {}
    end
  end

  describe "#count" do
    it "delegates to waypoint" do
      expect(waypoint).to receive(:count)
      pm_waypoint.count
    end
  end
end
