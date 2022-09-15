# frozen_string_literal: true

require "spec_helper"
require "reports/oclc_registration"

RSpec.describe Reports::OCLCRegistration do
  let(:org) { "umich" }
  let(:rep) { described_class.new(org) }

  it "provides a header that looks a certain way" do
    expect(rep.hed).to eq "local_oclc\tLSN\tInstitution symbol 852$a\tCollection ID\tAction Note 583$a\tAction date 583$c\tExpiration date 583$d"
  end

  it "looks up collection_id in a file based on oclc_sym" do
    expect(rep.collection_id("FOO")).to eq "123"
    expect(rep.collection_id("BAR")).to eq "456"
  end

  it "throws a key error if there is no mapping for an oclc_sym" do
    expect { rep.collection_id("QUX") }.to raise_error KeyError
  end

  it "formats commitments into the desired report format" do
    com = build(:commitment, oclc_sym: "FOO")
    expect(rep.fmt(com)).to eq [
      com.ocn,
      com.local_id,
      "FOO",
      "123",
      "committed to retain",
      com.committed_date,
      "20421231"
    ].join("\t")
  end

  it "outputs a report file with the expected name in the designated dir" do
    date = Time.new.strftime("%Y%m%d")
    outf = File.join(
      Settings.oclc_registration_report_path,
      "oclc_registration_#{org}_#{date}.tsv"
    )
    FileUtils.rm_f(outf)
    rep.run
    expect(rep.output_file).to eq outf
    expect(File.exist?(rep.output_file)).to be true
  end
end
