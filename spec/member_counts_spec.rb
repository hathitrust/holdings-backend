# frozen_string_literal: true

require "spec_helper"
require 'services'
require 'cluster'
require 'file_loader'
require 'holding_loader'
require 'ocn_resolution_loader'
require 'ht_item_loader'

RSpec.describe "member_counts_reports" do
  def small_data_file(str)
    "spec/testdata/small/#{str}"
  end

  let(:hathifile) { small_data_file('hathi_books_fake_oclc.tsv') }
  let(:oclc_concordance) { small_data_file('oclc_concordance.txt') }
  let(:mono_files) { Pathname.new('spec/testdata/small').glob('HT003*').map(&:to_s) }

  def reset_mongo_for_membership_specs
    Cluster.each(&:delete)
    FileLoader.new(batch_loader: OCNResolutionLoader.new).load(oclc_concordance)
    FileLoader.new(batch_loader: HtItemLoader.new).load(hathifile)

    holding_loader = HoldingLoader.new(update: false)
    mono_files.each do |mf|
      FileLoader.new(batch_loader: holding_loader).load(mf, skip_header_match: /\A\s*OCN/)
    end
    holding_loader.finalize

    require 'pry'; binding.pry
    true
  end

  before(:all) do
    %w(anu bu cmu).each do |mem|
      Services.ht_members.add_temp(HTMember.new(inst_id: mem, country_code: "us", weight: 1.0))
    end


  end

  after(:all) do
    Services.register(:ht_members) { mock_members }
    Services.register(:ht_collections) { mock_collections }
  end


  describe "Test the reset" do
    it "doesn't throw an error" do
      expect(reset_mongo_for_membership_specs).to be_truthy
      Cluster.each(&:delete)
    end
  end
end
