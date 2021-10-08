# frozen_string_literal: true

require "clusterable/ht_item"
require "faker"

FactoryBot.define do
  factory :ht_item, class: "Clusterable::HtItem" do
    ocns { [rand(1_000_000)] }
    item_id { rand(1_000_000).to_s }
    ht_bib_key { rand(1_000_000) }
    rights { ["pd", "ic", "icus", "cc", "pdus"].sample }
    access { ["allow", "deny"].sample }
    bib_fmt { ["BK", "CF", "MP", "MU", "MX", "SE", "VM"].sample }
    enum_chron { ["", "V.1"].sample }
    collection_code { ["MIU", "PU"].sample }

    trait :spm do
      bib_fmt { "BK" }
      enum_chron { "" }
    end

    trait :mpm do
      bib_fmt { "BK" }
      enum_chron { "V.#{rand(5).to_int}" }
    end

    trait :ser do
      bib_fmt { "SE" }
      enum_chron { "V.#{rand(200).to_int}" }
    end
  end
end
