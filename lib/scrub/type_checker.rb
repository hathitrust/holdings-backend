# frozen_string_literal: true

require "scrub/type_check_error"

module Scrub
  class TypeChecker
    attr_reader :organization, :new_types, :old_types

    def initialize(organization:, new_types: [], old_types: [])
      @organization = organization
      @new_types = new_types
      @old_types = old_types.any? ? old_types : get_old_types
    end

    def validate
      # If there are no old types, we'll allow loading any new type(s).
      return if old_types.empty?

      diff_types = new_types - old_types
      return if diff_types.empty?

      raise Scrub::TypeCheckError, [
        "There is a mismatch in item types.",
        "Previously loaded types: #{old_types.join(", ")}.",
        "Types being loaded now: #{new_types.join(", ")}.",
        "The diff is: #{diff_types.join(", ")}.",
        "This *can* be loaded but requires manual intervention."
      ].join(" ")
    end

    private

    def get_old_types
      Services.holdings_db[:holdings]
        .where(organization: organization)
        .select(:mono_multi_serial)
        .distinct
        .to_a
        .map { |hash| hash[:mono_multi_serial] }
    end
  end
end
