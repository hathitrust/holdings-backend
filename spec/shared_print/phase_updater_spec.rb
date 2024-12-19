require "cluster"
require "shared_print/finder"
require "shared_print/phase_updater"
require "shared_print/phases"

RSpec.xdescribe SharedPrint::PhaseUpdater do
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
end
