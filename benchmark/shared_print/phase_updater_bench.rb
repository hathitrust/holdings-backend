require "benchmark"
require "shared_print/phases"
require "shared_print/phase_updater"
$LOAD_PATH << "/usr/src/app/spec"
require "spec_helper"

class PhaseUpdaterBench
  def initialize
    @date = "2017-09-30 00:00:00 UTC"
    @phase0 = SharedPrint::Phases::PHASE_0
    @phase1 = SharedPrint::Phases::PHASE_1
    @updater = PhaseUpdater.new(@date, @phase1)
    @clusterables = []
  end

  def run
    setup
    Benchmark.measure { @updater.run }
    teardown
  end
  
  def setup
    # Create commitments with PHASE_1_DATE but PHASE_0
    1.upto(10) do
      @clusterables << build(:commitment, committed_date: @date, phase: @phase0)
    end
  end

  def teardown
    @clusterables.each do |c|
      c.delete
    end
  end
end

puts PhaseUpdaterBench.new.run
