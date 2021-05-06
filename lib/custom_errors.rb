# frozen_string_literal: true

# A collection of custom error classes, bare.
# Put a short usage note inside each error,
# even if the name makes it obvious what it do.

# Usage:

# require "custom_errors"
# ...
# raise SuperSpecificError.new("out of cheese")
# ...
# expect{fridge.empty()}.to raise_error(SuperSpecificError)

class CustomError < StandardError
  # Never raise this, raise a subclass
end

class FileNameError < CustomError
  # When a file is named wrong
end

class WellFormedFileError < CustomError
  # When a file is malformed
end

class WellFormedHeaderError < CustomError
  # When a file header is malformed
end

class MemberIdError < CustomError
  # When there's an error relating to a member_id / organization
end

class ColValError < CustomError
  # When a column in a file contains an bad value
end

class ItemTypeError < CustomError
  # When an invalid item type is used
end

class BadRecordError < CustomError
  # When there is enough wrong with a record to outright reject it
end
