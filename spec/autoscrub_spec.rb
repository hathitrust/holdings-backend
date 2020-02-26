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

    # Now testing that all the parts fit together.
    it "rejects files that are not well formed" do
      expect(
        autoscrub.well_formed_file?(
        'haverford_mono_full_20200101_headerless.tsv'
      )).to be(false)

      # Not ready to test yet
      # expect(
      #   autoscrub.well_formed_file?(
      #   'haverford_mono_full_20200101_header.tsv'
      # )).to be(true)
    end

    it "rejects ocns with no numbers in them" do
      expect(autoscrub.check_col_val('oclc', "xyz")).to eq([])
      expect(autoscrub.check_col_val('oclc', "")).to eq([])
      expect(autoscrub.check_col_val('oclc', " ")).to eq([])
      expect(autoscrub.check_col_val('oclc', "\t")).to eq([])
      expect(autoscrub.check_col_val('oclc', "0")).to eq([])
    end

    it "rejects funky ocns" do
      expect(autoscrub.check_col_val('oclc', "1.234E+56")).to eq([])
      expect(autoscrub.check_col_val('oclc', "123new456")).to eq([])
      expect(autoscrub.check_col_val('oclc', "(ABC)123")).to eq([])
      expect(autoscrub.check_col_val('oclc', "ABC123")).to eq([])
      expect(autoscrub.check_col_val('oclc', "000NEW")).to eq([])
    end

    it "rejects ocns with suffixes" do
      expect(autoscrub.check_col_val('oclc', "00123-x")).to eq([])
    end
    
    it "rejects ocns that are too big" do
      expect(autoscrub.check_col_val('oclc', "999999999999")).to eq([])
    end

    it "correctly uniqs multiple ocns" do
      expect(autoscrub.check_col_val('oclc', "555;555")).to eq([555])
      expect(autoscrub.check_col_val('oclc', "555 555")).to eq([555])
      expect(autoscrub.check_col_val('oclc', "555; 555")).to eq([555])
      expect(autoscrub.check_col_val('oclc', "555 ;555")).to eq([555])
      expect(autoscrub.check_col_val('oclc', "123; 456")).to eq([123,456])
      expect(autoscrub.check_col_val('oclc', "000123; 123")).to eq([123])
    end
    
    it "extracts the good part(s) from an ok ocn" do
      expect(autoscrub.check_col_val('oclc', "555")).to eq([555])
      expect(autoscrub.check_col_val('oclc', "(OCN)123")).to eq([123])
      expect(autoscrub.check_col_val('oclc', "(ocolc)123")).to eq([123])
      expect(autoscrub.check_col_val('oclc', "OCN123")).to eq([123])
      expect(autoscrub.check_col_val('oclc', "ocolc123")).to eq([123])
    end

    it "can do all the above ocn things in one go" do
      expect(autoscrub.check_col_val(
              'oclc',
              [
                "\t",
                '   ',
                '',
                '(a)123',
                '0',
                '00123-x',
                '123',
                '999999999999999',
                'ocn00123',
                'ocolc123',
                'xx',
              ].join(';')
            )).to eq([123])
    end

    it "accepts ok status and rejects anything else" do
      expect(autoscrub.check_col_val('status',"CH")).to eq(["CH"])
      expect(autoscrub.check_col_val('status',"LM")).to eq(["LM"])
      expect(autoscrub.check_col_val('status',"WD")).to eq(["WD"])
      expect(autoscrub.check_col_val('status',"")).to eq([])
      expect(autoscrub.check_col_val('status',"0")).to eq([])
      expect(autoscrub.check_col_val('status',"1")).to eq([])
    end

    it "accepts ok condition and rejects anything else" do
      expect(autoscrub.check_col_val('condition',"BRT")).to eq(["BRT"])
      expect(autoscrub.check_col_val('condition',"")).to eq([])
      expect(autoscrub.check_col_val('condition',"0")).to eq([])
      expect(autoscrub.check_col_val('condition',"1")).to eq([])
    end
end
