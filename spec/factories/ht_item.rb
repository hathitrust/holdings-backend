# frozen_string_literal: true

FactoryBot.define do
  factory :ht_item do
    ocns { [rand(1_000_000)] }
    item_id { rand(1_000_000).to_s }
    ht_bib_key { rand(1_000_000) }
    rights { ["pd", "ic", "icus", "cc", "pdus"].sample }
    bib_fmt { ["m", "s", "r"].sample }
  end
end
