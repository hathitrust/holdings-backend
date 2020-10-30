# frozen_string_literal: true

class FakeSerials

  def matches_htitem?(htitem)
    bibkeys.include?(htitem.ht_bib_key.to_i)
  end

  def initialize
    @bibkeys = Set.new
  end

  attr_reader :bibkeys
end

def mock_serials
  FakeSerials.new
end
