require 'autoscrub'

RSpec.describe Autoscrub do
    let(:member_id) {:haverford}
    let(:autoscrub) {described_class.new(member_id)}
    let(:data_dir) {__dir__ + '../testdata'}

    it "is an existing member" do
      expect(autoscrub.valid_member_id?(member_id)).to be(true)
      # Add negative test when you figure out how best to mock that.
    end

    it "accepts a valid filename" do
      ["haverford_mono_full_20200101_headerless.tsv",
       "haverford_mono_full_20200101_headerless.tsv.gz",
       "haverford_mono_full_20200101.tsv"
      ].each do |good_fn|
        expect(autoscrub.valid_filename?(good_fn)).to be(true)
      end
    end

    it "rejects an invalid filename" do
      ["1234rford_mono_full_55556677.tsv",
       "haverford_yolo_full_55556677.tsv",
       "haverford_mono_half_55556677.tsv",
       "haverford_mono_full_July4-1776.tsv",
       "haverford_mono_full_55556677.txt",
       "bc_mono_full_55556677.#{(['la']*10).join('.')}.tsv.gz"
      ].each do |bad_fn|
        expect(autoscrub.valid_filename?(bad_fn)).to be(false)
      end
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

    it "acceptss lines inside lenght requirements" do
      expect(autoscrub.number_of_cols([1] * 2)).to be(true)
      expect(autoscrub.number_of_cols([1] * 6)).to be(true)
    end

    it "rejects lines outside lenght requirements" do
      expect(autoscrub.number_of_cols([1] * 1)).to be(false)
      expect(autoscrub.number_of_cols([1] * 7)).to be(false)
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
      expect(autoscrub.check_col_val('oclc', "555CALLSAUL")).to eq([])
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

    it "accepts ok local_id" do
      ["123","i123","bib123","1"*50,"4137532|4|10162|"].
        each do |local_id|
        expect(autoscrub.check_col_val(
                'local_id',
                local_id
              )).to eq([local_id])
      end
    end

    it "rejects bad local_id" do
      expect(autoscrub.check_col_val('local_id',"1"*51)).to eq([])
      expect(autoscrub.check_col_val('local_id',"")).to eq([])
    end

    it "accepts good govdoc" do
      expect(autoscrub.check_col_val('govdoc',"1")).to eq(["1"])
      expect(autoscrub.check_col_val('govdoc',"0")).to eq(["0"])
    end

    it "rejects bad govdoc" do
      ["",
       "y",
       "yes",
       "00",
       "01",
       "10",
       "11",
      ].each do |govdoc|
        expect(autoscrub.check_col_val('govdoc', govdoc)).to eq([])
      end
    end

    it "accepts ok issns" do
      ["1234-1234",
       "1234-123X",
       "12341234",
       "1234123X",
       "1234-1234;2345-2345",
       "1234-123x;2345-234X",
      ].each do |issn|
        expect(autoscrub.check_col_val('issn', issn)).to eq([issn])
      end
    end

    it "rejects bad issns" do
      ["1234-SAUL",
       "CALL-1234",
       "CALL-SAUL",
       "234-2345",
       "2345-234",
       "23456-2345",
       "2345-23456",
      ].each do |issn|
        expect(autoscrub.check_col_val('issn', issn)).to eq([""])
      end
    end

    it "partially accepts mixed good/bad  issns" do
      ["1234-1234;1234-SAUL",
       "1234-1234;CALL-1234",
       "1234-1234;CALL-SAUL",
       "1234-1234;234-2345",
       "1234-1234;2345-234",
       "1234-1234;23456-2345",
       "1234-1234;2345-23456",
      ].each do |issn|
        expect(autoscrub.check_col_val('issn', issn)).to eq(["1234-1234"])
      end
    end

    it "currently allows anything in enumchron" do
      expect(autoscrub.check_col_val(
              'enumchron',
              "vol 1"
            )).to eq(["vol 1"])
    end

    it "allows well formed files" do
      expect(
        autoscrub.well_formed_file?(
        'haverford_mono_full_20200101_header.tsv'
      )).to be(true)
    end

    # Now testing that all the parts fit together.
    it "rejects files that are not well formed" do
      ['haverford_mono_full_20200101_headerless.tsv',
       'haverford_mono_full_20200101_notab.tsv',
       'haverford_mono_full_20200101_badocn.tsv'
      ].each do |f|
        expect(autoscrub.well_formed_file?(f)).to be(false)
      end
    end

end
