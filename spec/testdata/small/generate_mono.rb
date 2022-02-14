# frozen_string_literal: true

# Generate a small set of single-part monograph data for testing.
# See README.md for details. Make sure to update the README if you change the code.

require "securerandom"

a = "anu"
b = "bu"
c = "cmu"
schools = [a, b, c]

header = ["OCN", "BIB", "MEMBER_ID", "STATUS", "CONDITION", "DATE",
  "ENUM_CHRON", "TYPE", "ISSN", "N_ENUM", "N_CHRON", "GOV_DOC", "UUID"]

holdings = schools.each_with_object({}) { |s, h| h[s] = [] }

def newline(member, ocn, status: "CH", gov: "")
  [
    ocn,
    format("%09d", ocn),
    member,
    status,
    "",
    "2020-09-01",
    "",
    "mono",
    "",
    "",
    "",
    gov,
    SecureRandom.uuid
  ]
end

# Everyone has OCNs 1-10

schools.each do |s|
  (1..10).each do |oclc|
    holdings[s] << newline(s, oclc)
  end
end

# everyone have different versions of 11
holdings[a] << newline(a, 11)
holdings[b] << newline(b, 1100)
holdings[c] << newline(c, 1101)

# anu and cmu have different versions of 12
holdings[a] << newline(a, 12)
holdings[b] << newline(b, 1201)

# anu and bu have different versions of 13, both of which need the concordance
holdings[a] << newline(a, 1300)
holdings[c] << newline(c, 1301)

# anu has OCN 14, which appears in the hatihfiles only as 1400
holdings[a] << newline(a, 14)

# anu has three copies of 15
3.times do
  holdings[a] << newline(a, 15)
end

# everyone has five more things that no one else has
(21..25).each do |oclc|
  holdings[a] << newline(a, oclc)
end

(31..35).each do |oclc|
  holdings[b] << newline(b, oclc)
end

(41..45).each do |oclc|
  holdings[c] << newline(c, oclc)
end

# anu and bu share an OCN not in the hathifiles

[a, b].each { |school| holdings[school] << newline(school, 100) }

# And finally, anu has five other things that are not in the concordance,
# hathifiles, or any other school
(101..105).each { |oclc| holdings[a] << newline(a, oclc) }

# Now print it all out.
schools.each do |s|
  File.open("HT003_#{s}.mono.tsv", "w:utf-8") do |f|
    f.puts header.join("\t")
    holdings[s].each do |line|
      f.puts line.map(&:to_s).join("\t")
    end
  end
end
