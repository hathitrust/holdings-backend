require "marc"
require "date"

# Takes marc-xml files from exlibris and parses them into .tsv files
# that can be loaded into the HathiTrust print holdings db.
# Example:
#   bash phctl.sh parse parse-holdings-xml --organization foo --files /tmp/*.xml --output-dir /tmp --inline

# We are expecting each record to have the ControlFields 001 and 008
# and the DataFields 035 and ITM.

class ExLibrisHoldingsXmlParser
  attr_reader :organization, :files, :output_dir, :output_files, :record_count, :errors

  def initialize(organization:, files:, output_dir: Settings.local_report_path)
    @organization = organization
    @files = files
    @output_dir = output_dir
    @record_count = 0
    @errors = {}
    @output_files = {}
  end

  # Takes all files and prints all output records.
  def run
    # Create output files & print headers
    mon = output_file(type: "mon", header: %w[oclc local_id status condition enum_chron govdoc])
    ser = output_file(type: "ser", header: %w[oclc local_id issn govdoc])
    @output_files = {mon: mon, ser: ser}

    # Process input file by file, line by line
    main(@files) do |ht_record|
      case ht_record.item_type
      when "mon"
        mon.puts ht_record.to_mon_tsv
      when "ser"
        ser.puts ht_record.to_ser_tsv
      else
        raise ArgumentError, "unexpected item type #{ht_record.item_type}"
      end
    rescue ArgumentError => e
      @errors[e.message.to_s] ||= 0
      @errors[e.message.to_s] += 1
    end

    print_errors
    output_files.values.each { |f| f.close }
  end

  private

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

  # Start an output file with predictable name in the output dir.
  def output_file(type:, header: [])
    date = Date.today.strftime("%Y%m%d")
    file = File.open(
      File.join(output_dir, "#{@organization}_#{type}_full_#{date}.tsv"),
      "w"
    )
    file.puts header.join("\t")
    file
  end

  def print_errors
    if @errors.any?
      warn "Errors caught:"
      @errors.each do |etype, count|
        if count > 1
          # Compact identical errors
          warn "#{etype}: #{count}"
        else
          warn etype
        end
      end
    end
  end
end

# A HTRecord has a marc record and knows how to turn it into a tsv string.
class HTRecord
  def initialize(marc_record)
    @marc_record = marc_record # ... a Marc::Record!
  end

  # Should use the same order as HTRecord.header_tsv
  def to_tsv
    [item_type, oclc, local_id, status, condition, enum_chron, issn, govdoc]
      .join("\t").delete("\n")
  end

  def to_mon_tsv
    [oclc, local_id, status, condition, enum_chron, govdoc]
      .join("\t").delete("\n")
  end

  def to_ser_tsv
    [oclc, local_id, issn, govdoc]
      .join("\t").delete("\n")
  end

  def itm(x)
    unless @marc_record["ITM"]
      raise ArgumentError, "Record rejected for lacking an ITM field: #{@marc_record}"
    end

    @marc_record["ITM"][x]
  end

  def leader
    @leader ||= @marc_record.leader
  end

  def oclc
    if @marc_record["035"]
      @oclc = @marc_record["035"]["a"].strip
    else
      raise ArgumentError, "Record rejected for missing 035a (ocn): #{@record}"
    end
  end

  def local_id
    @local_id ||= ((item_type == "ser") ? @marc_record["001"].value : itm("d")).strip
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
    ].reject { |x| x.nil? || x.empty? }.map(&:strip).join(",")
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

  def govdoc
    @govdoc ||= is_us_govdoc? ? "1" : "0"
  end

  def is_us_govdoc?
    unless @marc_record["008"]
      raise ArgumentError, "Record rejected for missing 008 field: #{@marc_record}"
    end

    str_val = @marc_record["008"].value.downcase

    pubplace_008 = str_val[15, 3]
    govpub_008 = str_val[28]

    is_us?(pubplace_008) && govpub_008 == "f"
  end

  # via post-zephir processing "clean_pub_place"
  def is_us?(pub_place)
    return true if pub_place[2] == "u"
    return true if pub_place[0, 2] == "pr"
    return true if pub_place[0, 2] == "us"
    false
  end

  private

  def map_item_type(item_type)
    {
      "s" => "ser",
      "m" => "mon"
    }[item_type] || "mix"
  end

  def map_status(status)
    unless item_type == "ser"
      {
        "MISSING" => "LM",
        "LOST_LOAN" => "LM"
      }[status] || "CH"
    end
  end
end
