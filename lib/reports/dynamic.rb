# frozen_string_literal: true

require "services"
require "clusterable/commitment"
require "clusterable/holding"
require "clusterable/ht_item"
require "clusterable/ocn_resolution"

# This is an attempt at a piece of reusable dynamic reporting
# scaffolding, with which one can get basic reports like
# "all holdings by colby, with ocn and status" or
# "all commitments by arizona where condition is excellent"

module Reports
  class Dynamic
    attr_reader :base, :decorations, :restrictions
    def initialize(base: "", decorations: [], restrictions: [], log_toggle: 0)
      raise "not implemented"
      @base = validate_clusterable(base)
      @decorations = add_decorations(decorations)
      @restrictions = add_restrictions(restrictions)
      @log_toggle = log_toggle
      log [
        "new dynamic report!",
        "base: #{base}",
        "decorations: #{decorations.inspect}",
        "restrictions: #{restrictions.inspect}",
        "output_file: #{output_file}"
      ].join("\n")
    end

    def self.model
      # keys correspond to valid base values.
      {
        "commitments" => Clusterable::Commitment,
        "holdings" => Clusterable::Holding,
        "ht_items" => Clusterable::HtItem,
        "ocn_resolutions" => Clusterable::OCNResolution
      }
    end

    # a clusterable (e.g. @base) value must match a key in model.
    def validate_clusterable(clusterable)
      log "validate_clusterable(#{clusterable})"
      unless Dynamic.model.key?(clusterable)
        mk = Dynamic.model.keys.join(", ")
        raise ArgumentError, "clusterable not allowed: #{clusterable}. Must be one of #{mk}."
      end
      clusterable
    end

    # Decorations come in as an array of strings.
    # The strings should be "x.y" where x=on and y=key,
    # such that on is a model class, and key a field in that class.
    def add_decorations(decorations)
      log "add_decorations(#{decorations.inspect})"

      if decorations.empty?
        raise ArgumentError, "1+ decorations required, none given"
      end

      decoration_objects = []
      decorations.each do |d|
        unless d.is_a? String
          raise ArgumentError, "decoration input must be a String"
        end

        on, key = d.split(".")
        if on.nil? || key.nil?
          raise ArgumentError, "decoration (#{d}) must match <on>.<key>"
        end

        decoration_objects << Reports::Decoration.new(on: on, key: key)
      end

      if decoration_objects.empty?
        raise ArgumentError, "1+ decorations required, none passed validation"
      end

      decoration_objects
    end

    # Restrictions, unlike decorations, can be empty.
    # Turn input hashes, like {"holdings.organization" => "umich"}
    # into Dynamic::Restriction objects:
    # <Restriction, @on:"holdings", @key:"organization", @val:"umich", ...>
    def add_restrictions(restrictions)
      log "add_restrictions(#{restrictions.inspect})"
      restriction_objects = []
      restrictions.each do |r|
        unless r.is_a? Enumerable
          raise ArgumentError, "restriction input must be an Enumerable"
        end

        unless r.flatten.size == 2
          raise ArgumentError, "restriction input must be 2 elements long"
        end

        on, key = r.flatten.first.split(".")
        val = r.flatten.last
        restriction_objects << Reports::Restriction.new(on: on, key: key, val: val)
      end
      restriction_objects
    end

    # Puts it all together.
    def run
      File.open(output_file, "w") do |outf|
        outf.puts header
        records do |rec|
          outf.puts rec.join("\t")
        end
      end
    end

    def header
      @decorations.map(&:key).join("\t")
    end

    # Runs the query and yields the records
    def records
      return enum_for(:records) unless block_given?

      Cluster.where(restrictions_as_hash).no_timeout.to_a.each do |clusterable|
        clusterable.send(@base).each do |embedded_doc|
          # This is almost like a mongo aggregate,
          # where the `Cluster.where(...)`    is the outer `$match`,
          # the `clusterable.send(@base)` is the `$unwind: @base`,
          # and the `matching_record?(embedded_doc)` is the inner `$match`.
          # Almost. And perhaps that would have been the way to go.
          next unless matching_record?(embedded_doc)
          # If we passed matching_record?, then the restrictions are satisfied.
          # Get the fields in @decoration from the embedded doc, for the output.
          extracted_fields = @decorations.map { |d| embedded_doc.send(d.key) }

          if extracted_fields.empty?
            # We may be validating to the point where we can't end up here.
            # Keeping it during development but TODO remove it.
            raise ArgumentError, "No fields extractable from #{@base} document"
          end

          yield extracted_fields
        end
      end
    end

    def output_dir
      FileUtils.mkdir_p(
        File.join(
          Settings.dynamic_reports || "/tmp",
          base
        )
      ).first # returns an array, so
    end

    def output_file
      if @output_file.nil?
        ymd = Time.now.strftime("%Y-%m-%d")
        rand_str = SecureRandom.hex
        id = [ymd, rand_str].join("-")
        @output_file = File.join(output_dir, id) + ".tsv"
      end
      @output_file
    end

    private

    def restrictions_as_hash
      # from [ {a.b => c}, {d.e => f} ]
      # to   {  a.b => c,   d.e => f  }
      @restrictions.map do |r|
        [r.on_key, r.val]
      end.to_h
    end

    # Does the embedded doc under observation match all our @restrictions?
    def matching_record?(embedded_doc)
      matches = []
      @restrictions.each do |restriction|
        # If a restriction is {holdings.ocn => 5},
        # then check the embedded doc (a holdings rec),
        # and see if its restriction.key field (ocn)
        # equals the restriction val (5)?
        doc_field_val = embedded_doc.send(get_field(restriction.key))
        # Add a truth value to array.
        matches << (doc_field_val == restriction.val)
      end
      # For this embedded_doc, as we checked all restrictions,
      # did we add only trues? If so, the embedded_doc is a match.
      matches.all?(true)
    end

    # Given a string, figure out field. ("x.y"->"y", "y"->"y")
    def get_field(str)
      if /\./.match?(str)
        str.split(".").last
      else
        str
      end
    end

    # Route messages to the log
    def log(msg)
      puts("## " + msg) if @log_toggle == 1
    end
  end

  # Parent class to Decoration and Restriction.
  class QueryElement
    attr_reader :on, :key
    def initialize(on: nil, key: nil)
      @on = on
      @key = key
      validate!
    end

    def validate!
      unless Dynamic.model.key?(on)
        raise ArgumentError, "@on must be a key in Dynamic.model"
      end

      # E.g. given on:"holdings" and key:"organization"
      # look up "holdings" and get the model Clusterable::Holding,
      # check that the model contains the a field matching "organization"
      model_class = Dynamic.model[on]
      model_fields = model_class.fields

      unless model_fields.key?(key)
        raise ArgumentError, "@key (#{@key}) is not a field in #{model_class}"
      end
    end
  end

  # Not much else going on in Decoration. It made no sense for
  # Restriction to be a subclass of Decoration, so they both
  # inherit from QueryElement, and Restriction adds some stuff.
  class Decoration < QueryElement
    def initialize(on: nil, key: nil)
      super
    end
  end

  # A partial restriction on the return set.
  # The z part in a SELECT x FROM y WHERE z equivalent query.
  class Restriction < QueryElement
    attr_reader :val
    def initialize(on: nil, key: nil, val: nil)
      super(on: on, key: key)
      @val = cast_val(Dynamic.model[@on].fields[@key].options[:type], val)
    end

    def cast_val(cast, val)
      # see SharedPrint::UpdateRecord.cast
      # case cast
      # when Float
      #  val.to_i
      # else
      val
      # end
    end

    def on_key
      [on, ".", key].join
    end

    def to_hash
      # e.g. { "holdings.organization" => "umich" }
      {on + "." + key => val}
    end

    def to_s
      "<Restriction: @on:#{@on} @key:#{@key}, @val:#{@val}, @cast:#{@cast}>"
    end
  end
end
