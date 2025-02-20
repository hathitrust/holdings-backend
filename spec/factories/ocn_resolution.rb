# frozen_string_literal: true

require "clusterable/ocn_resolution"

FactoryBot.define do
  factory :ocn_resolution, class: "Clusterable::OCNResolution" do
    variant { rand(1..1_000_000) }
    canonical { variant + rand(1..1_000_000) }
  end
end
