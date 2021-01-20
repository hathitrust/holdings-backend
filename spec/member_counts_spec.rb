# frozen_string_literal: true

require "spec_helper"
require 'services'
require 'cluster'
require 'file_loader'
require 'holding_loader'
require 'ocn_resolution_loader'
require 'ht_item_loader'
require_relative 'testdata/small/generate_print_holdings'

RSpec.describe "member_counts_reports" do
  let(:oclc_concordance) { Pathname.new(__dir__) + 'testdata' + 'small' +  'oclc_concordance.txt' }

  def reset_mongo_for_membership_specs
    Cluster.each(&:delete)
    FileLoader.new(batch_loader: OCNResolutionLoader.new).load(oclc_concordance)
    SmallData.load!

    # Add something for each school that isn't in the hathifile

    %w[anu bu cmu].each do |school|
      2.times do
        ClusterHolding.new(build(:holding, organization: school)).cluster
      end
    end

    true
  end

  before(:all) do
    Cluster.each(&:delete)
    %w(anu bu cmu).each do |mem|
      Services.ht_members.add_temp(HTMember.new(inst_id: mem, country_code: "us", weight: 1.0))
    end

  end

  after(:all) do
    Services.register(:ht_members) { mock_members }
    Services.register(:ht_collections) { mock_collections }
    Cluster.each(&:delete)
  end

  describe "Test the reset" do
    it "doesn't throw an error" do
      expect(reset_mongo_for_membership_specs).to be_truthy
      require 'pry'; binding.pry
      true
    end
  end
end
