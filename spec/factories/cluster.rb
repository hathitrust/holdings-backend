# frozen_string_literal: true

FactoryBot.define do
  factory :cluster do
    ocns { [rand(1_000_000)] }
  end
end
