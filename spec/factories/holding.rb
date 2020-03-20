# frozen_string_literal: true

FactoryBot.define do
  factory :holding do
    ocns { [rand(1_000_000)] }
    organization { rand(50).to_s }
    local_id { rand(1_000_000).to_s }
    enum_chron { "" }
    status { "" }
    condition { "" }
    gov_doc_flag { false }
    mono_multi_serial { ["mono", "multi", "serial"].sample }
  end
end
