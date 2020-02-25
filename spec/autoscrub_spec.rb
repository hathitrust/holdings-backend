require 'autoscrub'

RSpec.describe Autoscrub do
    let(:member_id) {:haverford}
    let(:autoscrub) {described_class.new(member_id)}
    let(:data_dir) {__dir__ + '../testdata'}

    it "is an existing member" do
      expect(autoscrub.valid_member_id?(member_id)).to be(true)
      # Add negative test when you figure out how best to mock that.
    end

    it "knows a valid filename" do
      expect(autoscrub.valid_filename?(
              "haverford_mono_full_20200101_headerless.tsv"
            )).to be(true)

      expect(autoscrub.valid_filename?(
              "haverford_mono_full_20200101_headerless.tsv.gz"
            )).to be(true)

      expect(autoscrub.valid_filename?(
              "haverford_mono_full_20200101.tsv"
            )).to be(true)

      expect(autoscrub.valid_filename?(
              "1234rford_mono_full_55556677.tsv"
            )).to be(false) # bad member_id

      expect(autoscrub.valid_filename?(
              "haverford_yolo_full_55556677.tsv"
            )).to be(false) # bad item_type

      expect(autoscrub.valid_filename?(
              "haverford_mono_half_55556677.tsv"
            )).to be(false) # bad update_type

      expect(autoscrub.valid_filename?(
              "haverford_mono_full_July4-1776.tsv"
            )).to be(false) # bad date_str

      expect(autoscrub.valid_filename?(
              "haverford_mono_full_55556677.txt"
            )).to be(false) # bad rest

      expect(autoscrub.valid_filename?(
              "bc_mono_full_55556677.#{(['la']*10).join('.')}.tsv.gz"
            )).to be(false) # bad rest
    end

    it "rejects header lines that are not well formed" do
      expect(autoscrub.well_formed_header?(
              %w<mmsid>, 'multi')).to be(false)
      expect(autoscrub.well_formed_header?(
              %w<oclc local_id enumchron>, 'mono')).to be(false)
      expect(autoscrub.well_formed_header?(
              %w<oclc local_id enumchron>, 'multi')).to be(true)
      expect(autoscrub.well_formed_header?(
              %w<oclc local_id enumchron>, 'serial')).to be(false)      
    end

    it "rejects lines that are too long or too short" do
      expect(autoscrub.number_of_cols([1] * 1)).to be(false)
      expect(autoscrub.number_of_cols([1] * 2)).to be(true)
      expect(autoscrub.number_of_cols([1] * 6)).to be(true)
      expect(autoscrub.number_of_cols([1] * 7)).to be(false)
    end

    # TODO: more tests of low-ish level functions here
    
    # Now testing that all the parts fit together.
    it "rejects files that are not well formed" do
      expect(
        autoscrub.well_formed_file?(
        'haverford_mono_full_20200101_headerless.tsv'
      )).to be(false)

      expect(
        autoscrub.well_formed_file?(
        'haverford_mono_full_20200101_header.tsv'
      )).to be(true)
    end

    it "can tell a good ocn from a bad one" do
      expect(autoscrub.check_col_val('oclc', "xyz")).to eq([])
      expect(autoscrub.check_col_val('oclc', "1.234E+56")).to eq([])
      expect(autoscrub.check_col_val('oclc', "123new456")).to eq([])
      expect(autoscrub.check_col_val('oclc', "99999999999")).to eq([])
      expect(autoscrub.check_col_val('oclc', "")).to eq([])      
      expect(autoscrub.check_col_val('oclc', "555")).to eq([555])
      expect(autoscrub.check_col_val('oclc', "555;555")).to eq([555])
      expect(autoscrub.check_col_val('oclc', "555 555")).to eq([555])
      expect(autoscrub.check_col_val('oclc', "555; 555")).to eq([555])
      expect(autoscrub.check_col_val('oclc', "555 ;555")).to eq([555])
      expect(autoscrub.check_col_val('oclc', "123; 456")).to eq([123,456])
      expect(autoscrub.check_col_val('oclc', "000123; 123")).to eq([123])
      
      
    end
    
end
