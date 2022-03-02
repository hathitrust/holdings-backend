# frozen_string_literal: true

module SharedPrint
  # An individual update record. Consists of find-fields and update-fields
  class UpdateRecord
    attr_reader :fields
    def initialize(input_fields = {})
      @err = []
      @input_fields = validate(input_fields)
    end

    # Validate:
    # the presence of required fields,
    # the optional presence of optional fields,
    # and the presence of nothing else.
    def validate(input_fields)
      validated = {}

      # Required, used to find record
      req_fields.keys.each do |k|
        unless input_fields.key?(k)
          @err << "Missing required field #{k}"
        end
        validated[k] = [cast(k, input_fields.delete(k))]
      end

      # Optional, used to update record
      input_fields.each do |k, v|
        if opt_fields.key?(k)
          validated[k] = cast(k, input_fields.delete(k))
        else
          @err << "Unrecognized field #{k}:#{v}"
        end
      end

      if @err.any?
        raise ArgumentError, @err.join("\n")
      end

      validated
    end

    # When read from file, all vals are strings,
    # and may need to get cast before becoming the new val
    def cast(key, val)
      cast_to = all_fields[key]
      case cast_to
      when :string
        val # Do nothing, is already string
      when :integer
        val.to_i
      when :date_time
        DateTime.parse(val)
      when :bool
        {"true" => true, "false" => false}[val]
      when :array
        val.split(",").map(&:strip)
      else
        raise ArgumentError, "Did not know how to cast #{key} (= #{val})"
      end
    end

    # These are the fields an UpdateRecord uses to find a matching commitment,
    # and what they cast to.
    # A record must have all of these.
    # And this is how they must be called in the UpdateFile.
    def req_fields
      {
        local_id: :string,
        ocn: :integer,
        organization: :string
      }
    end

    # These are the fields that an UpdateRecord can update, and what they cast to.
    # A record should have at least 1+ of these.
    # And this is how they must be called in the UpdateFile.
    def opt_fields
      {
        committed_date: :date_time,
        facsimile: :bool,
        policies: :array, # spec probably calls these lending_policy/scanning_repro_policy
        local_bib_id: :string,
        local_item_id: :string,
        local_item_location: :string,
        local_shelving_type: :string,
        oclc_sym: :string, # might be called oclc_symbol in places, TODO: check that.
        retention_date: :date_time
      }
    end

    def all_fields
      @all_fields ||= req_fields.merge(opt_fields)
    end

    # Expose the keys and values that SharedPrint::Finder uses to find commitments.
    def finder_fields
      @input_fields.slice(*req_fields.keys)
    end

    # Expose the keys and values of the things that are being updated.
    def updater_fields
      keys = opt_fields.keys & @input_fields.keys
      @input_fields.slice(*keys)
    end
  end
end
