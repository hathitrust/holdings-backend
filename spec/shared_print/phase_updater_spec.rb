require "stackprof"
require "cluster"
require "shared_print/finder"
require "shared_print/phase_updater"
require "shared_print/phases"

RSpec.describe SharedPrint::PhaseUpdater do
  before(:each) do
    Cluster.collection.find.delete_many
  end
  it "updates `phase` on commitments based on `committed_date`" do
    # Make 5 commitments with a known committed_date
    # and a phase that needs updating.
    clusterables = []
    1.upto(5) do |i|
      clusterables << build(
        :commitment,
        ocn: i,
        phase: SharedPrint::Phases::PHASE_0,
        committed_date: SharedPrint::Phases::PHASE_1_DATE
      )
    end
    cluster_tap_save(*clusterables)
    # Verify that we loaded what we think we loaded:
    # 5 commitments with the same phase and the same date.
    original_commitments = SharedPrint::Finder.new(phase: [0]).commitments.to_a
    expect(original_commitments.count).to eq 5
    expect(original_commitments.map(&:phase).uniq).to eq [SharedPrint::Phases::PHASE_0]
    expect(original_commitments.map(&:committed_date).uniq).to eq [SharedPrint::Phases::PHASE_1_DATE]

    # Here we want to update to phase 1, to match the phase 1 date.
    phase_updater = described_class.new(
      SharedPrint::Phases::PHASE_1_DATE,
      SharedPrint::Phases::PHASE_1
    )
    phase_updater.run
    # Verify that the commitments now have phase 1.
    updated_commitments = SharedPrint::Finder.new(phase: [1]).commitments.to_a
    expect(updated_commitments.count).to eq 5
    expect(updated_commitments.map(&:phase).uniq).to eq [SharedPrint::Phases::PHASE_1]
    expect(updated_commitments.map(&:committed_date).uniq).to eq [SharedPrint::Phases::PHASE_1_DATE]
  end
  it "benchmarks thusly", :slow do
    # This test is marked as slow (building buncha commitments), and may be skipped.
    # add "--tag slow" to rspec invocation to include
    require "benchmark"
    date = "2017-09-30 00:00:00 UTC"
    phase0 = SharedPrint::Phases::PHASE_0
    phase1 = SharedPrint::Phases::PHASE_1
    updater = SharedPrint::PhaseUpdater.new(date, phase1)
    build_count = 1000
    clusterables = []
    # Create commitments with PHASE_1_DATE but PHASE_0
    1.upto(build_count) do
      clusterables << build(:commitment, committed_date: date, phase: phase0)
    end
    cluster_tap_save(*clusterables)
    puts "timer starts... now!"
    bench = Benchmark.measure { updater.run }
    puts "... and TIME! (#{bench.total})"
    # Expect to be able to update all clusterables in less than 1s.
    expect(bench.total).to be_between(0.0, 0.1)
  end
  it "profiles thusly", :slow do
    # This test is marked as slow (building buncha commitments), and may be skipped.
    # add "--tag slow" to rspec invocation to include
    date = "2017-09-30 00:00:00 UTC"
    phase0 = SharedPrint::Phases::PHASE_0
    phase1 = SharedPrint::Phases::PHASE_1
    updater = SharedPrint::PhaseUpdater.new(date, phase1)
    profile_path = "/tmp/phase_updater_profile.json"
    build_count = 10
    clusterables = []
    # Create commitments with PHASE_1_DATE but PHASE_0
    1.upto(build_count) do
      clusterables << build(:commitment, committed_date: date, phase: phase0)
    end
    cluster_tap_save(*clusterables)
    # Run under profiling
    profile = StackProf.run(raw: true) do
      updater.run
    end
    File.open(profile_path, "w") do |outf|
      outf.puts(JSON.pretty_generate(profile))
    end
    puts "wrote #{profile_path}"
    expect(File.exist?(profile_path)).to be true
  end
end
