# frozen_string_literal: true

require "clusterable/commitment"
require "faker"

FactoryBot.define do
  factory :commitment, class: "Clusterable::Commitment" do
    uuid { SecureRandom.uuid }
    organization { ["umich", "upenn", "smu"].sample }
    ocn { rand(1_000_000) }
    local_id { "lid_" + rand(100).to_s }
    oclc_sym { ["zcu", "UAB", "uiu", "mbb"].sample }
    committed_date { Faker::Date.between(from: 3.year.ago, to: 1.year.ago) }
    facsimile { [true, false].sample }

    trait :deprecated do
      deprecation_status { ["C", "D", "E", "L", "M"].sample }
      deprecation_date { Faker::Date.between(from: 1.year.ago, to: 3.week.ago) }
    end
  end
end
