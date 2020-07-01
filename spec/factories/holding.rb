# frozen_string_literal: true

FactoryBot.define do
  factory :holding do
    ocn { rand(1_000_000) }
    organization { ["umich", "carleton", "smu"].sample }
    local_id { rand(1_000_000).to_s }
    mono_multi_serial { ["mono", "multi", "serial"].sample }
    date_received { Date.today }
  end
end
