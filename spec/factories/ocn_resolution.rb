# frozen_string_literal: true

require "clusterable/ocn_resolution"

FactoryBot.define do
  factory :ocn_resolution, class: "Clusterable::OCNResolution" do
    deprecated { rand(1..1_000_000) }
    resolved { deprecated + rand(1..1_000_000) }
  end
end
