# frozen_string_literal: true

require "ocn_resolution"

FactoryBot.define do
  factory :ocn_resolution, class: "OCNResolution" do
    deprecated { rand(1_000_000) }
    resolved { rand(1_000_000) }
    ocns { [deprecated, resolved] }
  end
end
