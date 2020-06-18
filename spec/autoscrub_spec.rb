require 'autoscrub'

RSpec.describe Autoscrub do
  let(:member_id) {"haverford"}
  let(:autoscrub) {described_class.new(member_id)}
  let(:data_dir) {__dir__ + '../testdata'}

  describe "member_id handling" do  
    it "recognizes an existing member" do
      expect(autoscrub.valid_member_id?(member_id)).to be(true)
      # Add negative test when you figure out how best to mock that.
    end
    
    it "rejects a bad member_id" do
      expect{Autoscrub.new("failme")}.to raise_error(MemberIdError)
    end
    
    it "rejects an empty member_id" do
      expect{Autoscrub.new("")}.to raise_error(MemberIdError)
    end
    
    it "rejects a nil member_id" do
      expect{Autoscrub.new(nil)}.to raise_error(MemberIdError)
    end
  end

  describe "input file name" do
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
  end
  
  describe "input file header" do
    it "fails well_formed_header? if given a bad item_type" do
      expect(autoscrub.well_formed_header?(
              %w<oclc local_id>, nil)).to be(false)
      expect(autoscrub.well_formed_header?(
              %w<oclc local_id>, "")).to be(false)
      expect(autoscrub.well_formed_header?(
              %w<oclc local_id>, "books")).to be(false)
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
  end

  describe "line in input file" do  
    it "accepts lines inside length requirements" do
      expect(autoscrub.number_of_cols([1] * 2)).to be(true)
      expect(autoscrub.number_of_cols([1] * 6)).to be(true)
    end
    
    it "rejects lines outside length requirements" do
      expect(autoscrub.number_of_cols([1] * 1)).to be(false)
      expect(autoscrub.number_of_cols([1] * 7)).to be(false)
    end
  end

  describe "OCN handling" do
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
  end


  describe "field value extraction" do
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
  end

  describe "enumchron normalization" do
    # Sadly, needs more tests, or the code needs to be replaced completely.
    it "currently allows anything in enumchron" do
      ec = 'enumchron'
      expect(autoscrub.check_col_val(ec, "vol 1")).to eq(["vol:1", nil])
      expect(autoscrub.check_col_val(ec, "1")).to eq(["1", nil])
      expect(autoscrub.check_col_val(ec, "")).to eq([nil, nil])
      expect(autoscrub.check_col_val(ec, "pt.1 1970")).to eq(["1","1970"])
      expect(autoscrub.check_col_val(ec, "01 (v. 1)")).to eq(["01:1",nil])
      expect(autoscrub.check_col_val(ec, "1970")).to eq([nil,"1970"])
      expect(autoscrub.check_col_val(ec, "1970-1971")).to eq([nil,"1970-1971"])
      expect(autoscrub.check_col_val(ec, "1970-1971 (no.20)")).to eq(["20","1970-1971"])
      expect(autoscrub.check_col_val(ec, "1970, spring")).to eq([nil, "1970 spring"])
      expect(autoscrub.check_col_val(ec, "1970, suppl")).to eq(["suppl", "1970"])
      expect(autoscrub.check_col_val(ec, "v.6a pt.2")).to eq(["6a:2", nil])
      expect(autoscrub.check_col_val(ec, "1970 v.1")).to  eq(["1", "1970"])
      expect(autoscrub.check_col_val(ec, "1970,v.1")).to  eq(["1", "1970"])
      expect(autoscrub.check_col_val(ec, "1970, v.1")).to eq(["1", "1970"])
      expect(autoscrub.check_col_val(ec, "V.8 How to Price Meats")
            ).to eq(["8:How:to:Price:Meats", nil])
      
      # buggy ones (i.e. ecparser could do a better job here,
      # but tests are controlling that behavior hasn't changed):
      expect(autoscrub.check_col_val(ec, "1970;v.1")).to  eq(["1", nil])
      expect(autoscrub.check_col_val(ec, "v.7 (2201-5600)")).to eq(["7", "2201-5600"])
      expect(autoscrub.check_col_val(ec, "1970;no.4")).to eq([nil, "1970no.4"])
      expect(autoscrub.check_col_val(ec, "1970;nos.4-5")).to eq([nil, "1970nos.4-5"])
      expect(autoscrub.check_col_val(ec, "Lev25-30;Rdr")).to eq(["25", nil])
      # Makes sense, ish:
      expect(autoscrub.check_col_val(ec, "v.3, Gr.8")).to  eq(["3:8", nil])
      expect(autoscrub.check_col_val(ec, "v.3, SEC.8")).to eq(["3:8", nil])
      # ... but then:
      expect(autoscrub.check_col_val(ec, "v.3/SEC.8")).to eq(["8", nil])
    end
  end
  
  it "allows well formed lines" do
    expect(
      autoscrub.well_formed_line?(
      %w[123 i789],
      'mono',
      {
        "oclc"=>0,
        "local_id"=>1
      })).to be(true)
    
    expect(
      autoscrub.well_formed_line?(
      %w[123 i789 CH BRT 1],
      'mono',
      {
        "oclc"=>0,
        "local_id"=>1,
        "status"=>2,
        "condition"=>3,
        "govdoc"=>4
      })).to be(true)
    
    expect(
      autoscrub.well_formed_line?(
      %w[123 i789 CH v.1 BRT 1],
      'multi',
      {
        "oclc"=>0,
        "local_id"=>1,
        "status"=>2,
        "enumchron"=>3,
        "condition"=>4,
        "govdoc"=>5
      })).to be(true)

    expect(
      autoscrub.well_formed_line?(
      %w[123 i789 1234-567X],
      'serial',
      {
        "oclc"=>0,
        "local_id"=>1,
        "issn"=>2
      })).to be(true)
  end

  it "allows well formed files" do
    expect(
      autoscrub.well_formed_file?(
      'haverford_mono_full_20200101_header.tsv'
    )).to be(true)
  end

  # Now testing that all the parts fit together.
  it "rejects files that are not well formed" do
    [
      "haverford_mono_full_20200101_headerless.tsv",
      "haverford_mono_full_20200101_notab.tsv"     ,
      "/dev/null"
    ].each do |fn|
      expect(autoscrub.well_formed_file?(fn)).to be(false)
    end

  end

  it "rejects malformed lines" do
    h = {"oclc"=>0,"local_id"=>1}
    expect(autoscrub.well_formed_line?([], 'mono', h)).to be(false)
    expect(autoscrub.well_formed_line?(['',''],'mono', h)).to be(false)
    expect(autoscrub.well_formed_line?(['','i789'],'mono', h)).to be(false)

    # number of cols must match number of cols in header
    expect(autoscrub.well_formed_line?(['123'],'mono', h)).to be(false)
    expect(autoscrub.well_formed_line?(['123', 'b123'],'mono', h)).to be(true)
    expect(autoscrub.well_formed_line?(['123', 'c123', 'c123'],'mono', h)).to be(false)
  end

  it "does not process holdings when member id does not match member id of file" do
    cornell_file = "cornell_mono_full_20200324_head100.tsv"
    expect(
      described_class.new("someone_else", cornell_file).scrub_files
    ).to eq({cornell_file => false})
  end
  
  describe "log file" do
    # TODO: clean up to remove relative paths;
    # consider putting some stuff in a temporary directory for testing e.g. w/ tmpdir

    let(:testfile_id) { "cornell_mono_full_20200324_head100" }
    let(:fixtures_path) { File.dirname(__FILE__) + "/../testdata" }
    let(:session_log) { "#{fixtures_path}/session_cornell_#{today}.log.txt" }
    let(:holdings_log) { "#{fixtures_path}/#{testfile_id}_#{today}.log.txt" }
    let(:holdings_file) { "#{fixtures_path}/#{testfile_id}.tsv" }
    let(:today) { Time.now.strftime("%Y%m%d") }

    def scrub_testdata
      FileUtils.rm_f(session_log)
      FileUtils.rm_f(holdings_log)
      Autoscrub.new("cornell", holdings_file).scrub_files
    end

    it "creates a log file named with the processed date" do
      scrub_testdata
      expect(File).to exist(holdings_file)
    end

    it "creates a session log file named with the institution id and the processed date"
    it "session log indicates whether or not the file was accepted or rejected"
    it "holdings log indicates whether or not the file was accepted or rejected"
    it "contains stats on all the things that were right & wrong"
  end

  it "all works together" do
    f1 = "haverford_mono_full_20200101_header.tsv"
    # f1 = "/dev/null"
    expect(
      described_class.new(
      member_id,
      f1
    ).scrub_files
    ).to eq({f1 => true})
  end
  
end
