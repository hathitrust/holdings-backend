require "marc"
require "pry"

# Takes marc-xml files from exlibris and parses them into .tsv files
# that can be loaded into the HathiTrust print holdings db.
# Example:
#   $ bundle exec ruby bin/ex_libris_holdings_xml_parser.rb xlib1.xml xlib2.xml > holdings.tsv

# We are expecting each record to have the ControlFields 001 and 008
# and the DataFields 035 and ITM.

class ExLibrisHoldingsXmlParser
  def initialize
    @files = ARGV
    @record_count = 0
    @errors = {}
  end

  # Takes all files and prints all output records.
  def run
    puts HTRecord.header_tsv

    main(@files) do |ht_record|
      puts ht_record.to_tsv
    rescue ArgumentError => e
      @errors[e.message.to_s] ||= 0
      @errors[e.message.to_s] += 1
    end
    # Print any errors caught above
    if @errors.any?
      warn "Errors caught:"
      @errors.each do |etype, count|
        warn "#{etype}: #{count}"
      end
    end
  end

  # Open each file, read its xmlrecords and yield HTRecords
  def main(files)
    files.each do |file|
      MARC::XMLReader.new(file).each do |marc_record|
        @record_count += 1
        ht_record = HTRecord.new(marc_record)
        yield ht_record
      end
    end
  end
end

# A HTRecord has a marc record and knows how to turn it into a tsv string.
class HTRecord
  def initialize(marc_record)
    @marc_record = marc_record # ... a Marc::Record!
  end

  # Should use the same order as to_tsv
  def self.header_tsv
    %w[item_type oclc local_id status condition enum_chron issn govdoc].join("\t")
  end

  # Should use the same order as HTRecord.header_tsv
  def to_tsv
    [item_type, oclc, local_id, status, condition, enum_chron, issn, govdoc]
      .join("\t").delete("\n")
  end

  def itm(x)
    @marc_record["ITM"][x]
  end

  def leader
    @leader ||= @marc_record.leader
  end

  def oclc
    if @marc_record["035"]
      @oclc = @marc_record["035"]["a"].strip
    else
      raise ArgumentError, "Missing oclc"
    end
  end

  def local_id
    @local_id ||= (item_type == "ser" ? @marc_record["001"].value : itm("d")).strip
  end

  def condition
    @condition ||= itm("c")
  end

  def item_type
    @item_type ||= map_item_type(leader[7])
  end

  # ExLibris say: ITM|a: volume, ITM|b: issue, ITM|i: year, ITM|j: month
  def enum_chron
    @enum_chron ||= [
      itm("a"), # volume
      itm("b"), # issue
      itm("i"), # year
      itm("j") ## month
    ].reject{ |x| x.nil? || x.empty? }.map(&:strip).join(",")
  end

  def status
    @status ||= map_status(itm("k"))
  end

  def issn
    if item_type == "ser"
      if @marc_record.fields("022").any?
        @marc_record["022"]["a"]
      else
        []
      end
    end
  end

  # double triple quadruple check that 17 and 28 are correct and using the right index (0/1)
  def govdoc
    str_val = @marc_record["008"].to_s
    @govdoc ||= ([str_val[17], str_val[28]].join == "uf")
  end

  private
  # These remaining private methods are essentially mappings

  # Todo: Do we not need to map this?
  def map_condition
    # BRT if BRITTLE, DAMAGED, DETERIORATING, FRAGILE
  end

  def map_item_type(item_type)
    {
      "s" => "ser",
      "m"   => "mon",
    }[item_type] || "mix"
  end

  def map_status(status)
    unless item_type == "ser"
      {
        "MISSING" => "LM",
        "LOST_LOAN"  => "LM",
      }[status] || "CH"
    end
  end
end

# Parse any incoming files, output to stdout.
if $0 == __FILE__
  ExLibrisHoldingsXmlParser.new.run
end
