# frozen_string_literal: true

FactoryBot.define do
  factory :serial do
    record_id { rand(1_000_000) }
    ocns { [rand(1_000_000)] }
    issns { [rand(1_000_000).to_s] }
    locations { ["BUHR", "HATCH", "SCI"].sample }
  end
end
