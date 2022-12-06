# frozen_string_literal: true

require "securerandom"
require "clusterable/holding"

FactoryBot.define do
  factory :holding, class: "Clusterable::Holding" do
    ocn { rand(1_000_000) }
    organization { ["umich", "upenn", "smu"].sample }
    local_id { rand(1_000_000).to_s }
    mono_multi_serial { ["mix", "mon", "spm", "mpm", "ser"].sample }
    date_received { Date.today }
    condition { "" }
    issn {}
    status {}
    uuid { SecureRandom.uuid }
    gov_doc_flag { [true, false].sample }

    trait :all_fields do
      issn { format("%04d-%04d", rand(1000), rand(1000)) }
      status { ["CH", "LM", "WD"].sample }
      condition { "BRT" }
    end
  end
end
