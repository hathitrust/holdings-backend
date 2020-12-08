# frozen_string_literal: true

require "spec_helper"

RSpec.describe "etas_overlap_report" do
  def small_data_file(str)
    "spec/testdata/small/#{str}"
  end

  let(:hathifile) { small_data_file('hathi_books_fake_oclc.tsv')}
  let(:oclc_concordance) { small_data_file('oclc_concordance')}
  let(:mono_files) { %w[HT003_anu.mono HT003_bu.mono HT003_cmu.mono ]}

  def reset_mongo_for_membership_specs
    Cluster.each(&:delete)
    FileLoader.new(batch_loader: HtItemLoader.new).load(hathifile)
    FileLoader.new(batch_loader: OCNResolutionLoader.new).load(oclc_concordance)

    holding_loader = HoldingLoader.new(update: false)
    mono_files.each do |mf|
      FileLoader.new(batch_loader: holding_loader).load(mf, skip_header_match: /\A\s*OCN/)
    end
    holding_loader.finalize
    true
  end


  describe "Test the reset" do
    it "doesn't throw an error" do
      expect(reset_mongo_for_membership_specs).to be_truthy
    end
  end
end
