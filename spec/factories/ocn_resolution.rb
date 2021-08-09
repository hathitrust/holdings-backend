# frozen_string_literal: true

require "clusterable/ocn_resolution"

FactoryBot.define do
  factory :ocn_resolution, class: "Clusterable::OCNResolution" do
    deprecated { rand(1_000_000) }
    resolved { rand(1_000_000) }
    ocns { [deprecated, resolved] }
  end
end
