# frozen_string_literal: true

require "digest"

this_finder   = __FILE__
this_checksum = Digest::MD5.file(this_finder)
dir           = File.dirname(this_finder)

if File.exist?(File.join(dir, "lib"))
  # We found lib in the current dir and we're done.
  $LOAD_PATH.unshift(File.join(dir, "lib"))
elsif File.exist?(File.join(dir, "..", "lib_finder.rb"))
  # No lib/ in this dir but there's another lib_finder above, so recurse upwards.
  up_finder   = File.join(dir, "..", "lib_finder.rb")
  up_checksum = Digest::MD5.file(up_finder)
  # But only if the up_finder is identical to this_finder
  if this_checksum == up_checksum
    require_relative "../lib_finder"
  else
    raise [
      "Lib finder checksum mismatch!",
      "#{this_checksum}\t#{this_finder}",
      "!=",
      "#{up_checksum}\t#{up_finder}"
    ].join("\n")
  end
end
