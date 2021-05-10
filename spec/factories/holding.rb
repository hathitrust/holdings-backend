# frozen_string_literal: true

require "securerandom"
require "holding"

FactoryBot.define do
  factory :holding do
    ocn { rand(1_000_000) }
    organization { ["umich", "upenn", "smu"].sample }
    local_id { rand(1_000_000).to_s }
    mono_multi_serial { ["mono", "multi", "serial"].sample }
    date_received { Date.today }
    condition { "" }
    uuid { SecureRandom.uuid }
  end
end
