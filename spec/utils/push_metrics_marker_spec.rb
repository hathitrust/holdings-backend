# frozen_string_literal: true

require "utils/push_metrics_marker"
require "prometheus/client/push"

RSpec.describe Utils::PushMetricsMarker do
  let(:batch_size) { rand(100) }
  let(:seconds_so_far) { rand(100) }
  let(:records_so_far) { rand(100) }
  let(:success_interval) { 24 * 60 * 60 * rand(7) }

  let(:marker) do
    instance_double(Milemarker,
      final_line: true,
      total_seconds_so_far: seconds_so_far,
      count: records_so_far).tap do |d|
      allow(d).to receive(:on_batch).and_yield(d)
    end
  end

  let(:pushgateway) { instance_double(Prometheus::Client::Push, add: true) }
  let(:registry) { instance_double(Prometheus::Client::Registry) }
  let(:metrics) do
    {
      duration: instance_double(Prometheus::Client::Gauge, set: true),
      last_success: instance_double(Prometheus::Client::Gauge, set: true),
      records_processed: instance_double(Prometheus::Client::Gauge, set: true),
      success_interval: instance_double(Prometheus::Client::Gauge, set: true)
    }
  end

  let(:params) do
    {
      marker: marker,
      registry: registry,
      metrics: metrics,
      pushgateway: pushgateway
    }
  end

  let(:pm_marker) do
    described_class.new(batch_size, **params)
  end

  describe "#initialize" do
    it "can be constructed" do
      expect(pm_marker).not_to be(nil)
    end

    it "sets initial values for duration and records processed" do
      expect(metrics[:duration]).to receive(:set).with(seconds_so_far)
      expect(metrics[:records_processed]).to receive(:set).with(records_so_far)

      pm_marker
    end

    it "doesn't set last success" do
      expect(metrics[:last_success]).not_to receive(:set)

      pm_marker
    end

    it "by default doesn't set success interval" do
      expect(metrics[:success_interval]).not_to receive(:set)

      pm_marker
    end

    it "sets success interval metric with constructor param" do
      expect(metrics[:success_interval]).to receive(:set).with(success_interval)

      described_class.new(batch_size, **params.merge({success_interval: success_interval}))
    end

    it "pushes initial metrics to pushgateway" do
      expect(pushgateway).to receive(:add).with(registry)

      pm_marker
    end
  end

  describe "#incr" do
    it "delegates to marker" do
      expect(marker).to receive(:incr)
      pm_marker.incr
    end
  end

  describe "#final_line" do
    it "delegates to milemarker" do
      expect(marker).to receive(:final_line)

      pm_marker.final_line
    end

    it "returns what milemarker returns" do
      allow(marker).to receive(:final_line).and_return("milemarker return")

      expect(pm_marker.final_line).to eq("milemarker return")
    end

    it "updates the metrics" do
      expect(metrics[:duration]).to receive(:set).with(seconds_so_far)
      expect(metrics[:records_processed]).to receive(:set).with(records_so_far)
      expect(metrics[:last_success]).to receive(:set).with(Time.now.to_i)

      pm_marker.final_line
    end

    it "pushes metrics to pushgateway" do
      expect(pushgateway).to receive(:add).with(registry)

      pm_marker.final_line
    end
  end

  describe "#on_batch" do
    it "delegates to marker" do
      expect(marker).to receive(:on_batch)

      pm_marker.on_batch {}
    end

    it "updates the metrics" do
      expect(metrics[:duration]).to receive(:set).with(seconds_so_far)
      expect(metrics[:records_processed]).to receive(:set).with(records_so_far)

      pm_marker.on_batch {}
    end

    it "pushes metrics to pushgateway" do
      expect(pushgateway).to receive(:add).with(registry)

      pm_marker.on_batch {}
    end

    it "doesn't overwrite last success metric" do
      expect(metrics[:last_success]).not_to receive(:set)

      pm_marker.on_batch {}
    end
  end

  describe "#count" do
    it "delegates to marker" do
      expect(marker).to receive(:count)
      pm_marker.count
    end
  end
end
