# frozen_string_literal: true

# parser - a parser for enum/chron data
# Takes an enumeration/chronology string and
# classifies all terms as either enum and chron,
# PJU - May 2012
# Copyright (C), University of Michigan Library

class EnumChronParser
  attr_accessor :enum, :chron

  DOT_PATTERN = /\.\s+([^\.]+)/.freeze
  DATE_PATTERN = /\. [0-2]\d{3}/.freeze

  # chron patterns
  DATE_RE = /^([a-z]{0,7}\.)?[12]\d{3}/.freeze
  MONTH_RE = /(jan|january|febr?|february|mar|march|
             apr|april|may|june?|
             july?|aug|august|sept?|september|
             oct|october|nov|november|dec|december)
             [\.\?]?/ix.freeze
  DAY_RE = /[0-3]?[0-9](th|st|rd|nd)$/i.freeze
  DAY_RE1 = /([0-9]{1,4})(th|st|rd|nd)?/i.freeze
  DAY_RE2 = /[0-3]?[0-9](th|st|rd|nd)?/.freeze
  MONTH_DAY_RE = /(#{MONTH_RE} #{DAY_RE1})/.freeze
  MONTH_SPAN_RE = /(#{MONTH_RE}-#{MONTH_RE})/.freeze
  DAY_SPAN_RE = /(#{DAY_RE2}-#{DAY_RE2})/.freeze
  DATE_MONTH_SPAN_RE = /(#{DATE_RE}\-#{MONTH_RE})/.freeze
  MONTH_DAY_SPAN_RE = /(#{MONTH_RE} #{DAY_SPAN_RE})/.freeze
  SEASONS_RE = /(spring|summer|winter|fall)/i.freeze

  # enum patters
  ENUM_RE = /(v\.|n\.s\.)/.freeze
  LONG_NUM_RE = /^([0-9]{5,})/.freeze

  # Misc patterns
  REN_RE_1 = /([A-Za-z0-9\.]+)\((\d{2,4})\)/.freeze
  REN_RE_2 = /([A-Z])(\d+)/i.freeze
  REN_RE_3 = /\w+\.(.*)/.freeze
  REN_RE_4 = /[A-Za-z]+[\s]+([\d]+)/.freeze
  QUOTED_BSLASH = /\"\\\"/.freeze
  DOT_SPACE = /\.\s+/.freeze
  SPACE = /\s/.freeze
  C_AZ = /C[a-z]*\./i.freeze
  DOUBLE_COLON = /::/.freeze
  ALPHANUM = /[a-z0-9]/i.freeze
  TRAIL_HYPHEN = /\-$/.freeze

  def initialize
    @enum  = []
    @chron = []
  end

  def preprocess(str)
    str.tr! ",", " "
    str.tr! ":", " "
    str.delete! ";"
    str.gsub!(" - ", "-")
    str.tr! "(", " "
    str.tr! ")", " "
    # remove spaces after dots except when followed by a date
    newstr = dot_sub(str)
    # recover the 'n.s.' pattern
    newstr.sub!("n.s.", "n.s. ")
    newstr.gsub!(/\s\s/, " ")
  end

  def dot_sub(mstr)
    # remove spaces after dots except when followed by a date

    positions = mstr.enum_for(:scan, DOT_PATTERN).map { Regexp.last_match.begin(0) }
    iter = 0
    positions.each do |p|
      i = p - iter
      unless mstr[i..i+5]&.match?(DATE_PATTERN)
        mstr.sub!(". ", ".")
        iter += 1
      end
    end
    mstr
  end

  def add_to_enum(enum)
    # normal_e = normalize_enum(e)
    @enum.push(enum)
  end

  def add_to_chron(chron)
    # normal_c = normalize_chron(c)
    @chron.push(chron)
  end

  def enum_str
    @enum.join(" ")
  end

  def chron_str
    @chron.join(" ")
  end

  def clear_fields
    self.enum  = []
    self.chron = []
  end

  def normalized_chron
    ## TO DO:  add season codes
    # first chron
    return if @chron.empty?

    chron = if @chron.class == Array
      @chron.join(" ")
    else
      @chron
    end
    # dates
    newchron = if chron.to_i
      if chron.length == 2
        if chron.to_i > 0 && chron.to_i < 12
          "20" << chron
        else
          "19" << chron
        end
      else
        chron
      end
    else
      chron
    end
    newchron
  end

  def normalized_enum
    new_enum = []
    return if @enum.empty?

    enum = if @enum.class != Array
      [@enum]
    else
      @enum
    end
    enum.each do |en|
      if en[-1] == "."
        en = en[0..-2]
      end

      ren = en.gsub QUOTED_BSLASH, ""
      ren = en.gsub DOT_SPACE, "."
      ren = ren.gsub SPACE, ""
      ren = ren.delete "("
      ren = ren.delete ")"
      ren = ren.delete "["
      ren = ren.delete "]"
      ren = ren.delete ","
      ren = ren.delete '"'
      ren = ren.gsub C_AZ, ""
      # handle special cases

      if ren =~ REN_RE_1
        ren = "#{Regexp.last_match(1)} #{Regexp.last_match(2)}"
      end
      if ren =~ REN_RE_2
        ren = "#{Regexp.last_match(1)}.#{Regexp.last_match(2)}"
      end
      if ren =~ REN_RE_3
        ren = Regexp.last_match(1)
      end
      if ren =~ REN_RE_4
        ren = Regexp.last_match(1)
      end
      new_enum.push(ren)
    end
    renum = if new_enum.length > 1
      new_enum.join(":")
    else
      new_enum[0]
    end
    renum = renum.gsub DOUBLE_COLON, ":"
    if renum[-1] == ":"
      renum = renum[0..-2]
    end
    if renum[0] == ":"
      renum = renum[1..-1]
    end
    renum
  end

  def parse(input_str)
    # clear current data
    clear_fields

    # preprocess
    pstr = preprocess(input_str)

    ### classify enum vs chron ###
    begin
      # "pullout" parses run 1st, followed by inlines
      if input_str&.match?(MONTH_DAY_SPAN_RE)
        matches = input_str.scan(MONTH_DAY_SPAN_RE)
        matches.each do |m|
          # $stderr.puts "'#{m}'"
          add_to_chron(m[0])
          input_str = input_str.gsub!(m[0], "")
        end
      end
      if input_str&.match?(MONTH_SPAN_RE)
        matches = input_str.scan(MONTH_SPAN_RE)
        matches.each do |m|
          # $stderr.puts "'#{pullout}'"
          add_to_chron(m[0])
          input_str = input_str.gsub!(m[0], "")
        end
      end
      if input_str&.match?(MONTH_DAY_RE)
        matches = input_str.scan(MONTH_DAY_RE)
        matches.each do |m|
          # $stderr.puts "'#{pullout}'"
          add_to_chron(m[0])
          input_str = input_str.gsub!(m[0], "")
        end
      end
      return unless ALPHANUM.match?(input_str)
    rescue StandardError => e
      puts e.message
      puts e.backtrace.inspect
      warn "[Parser] Problem parsing '#{input_str}'"
      return
    end

    # straight inline parse of what's left
    bits = input_str.split
    # deal with date-month case
    bits.each do |b|
      if b&.match?(DATE_MONTH_SPAN_RE)
        sub_b = b.split("-")
        i = bits.index(b)
        bits.insert(i, sub_b[0])
        bits.insert(i+1, sub_b[1])
        bits.delete(b)
      end
    end
    bits.each do |b|
      # match chron primaries
      if b =~ ENUM_RE || b =~ LONG_NUM_RE
        add_to_enum(b)
      elsif b =~ DATE_RE || b =~ MONTH_DAY_RE || b =~ MONTH_RE || b =~ SEASONS_RE
        b.delete!("-") if TRAIL_HYPHEN.match?(b) # delete trailing '-'
        add_to_chron(b)
      else
        add_to_enum(b)
      end
    end
  end

  # For debug purposes.
  # Invoke: ruby enum_chron_parser.rb <file>
  def self.parse_file(file)
    File.open(file).each_line do |line|
      line.strip!
      ecp = EnumChronParser.new
      ecp.parse(line)
      n_enum  = ecp.normalized_enum
      n_chron = ecp.normalized_chron
      puts [n_enum, n_chron].join("\t")
    end
  end

  private :add_to_enum, :add_to_chron, :preprocess, :dot_sub, :clear_fields, :enum=

end

if $PROGRAM_NAME == __FILE__
  EnumChronParser.parse_file(ARGV.shift)
end
