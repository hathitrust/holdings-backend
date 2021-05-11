# frozen_string_literal: true

require "cluster"

FactoryBot.define do
  factory :cluster do
    ocns { [rand(1_000_000)] }
  end
end
