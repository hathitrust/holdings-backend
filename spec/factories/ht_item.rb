# frozen_string_literal: true

require "clusterable/ht_item"
require "faker"

FactoryBot.define do
  factory :ht_item, class: "Clusterable::HtItem" do
    ocns { [rand(1..1_000_000)] }
    item_id { "test." + rand(1..1_000_000).to_s }
    ht_bib_key { rand(1..1_000_000) }
    rights { ["pd", "ic", "icus", "cc", "pdus"].sample }
    access { ["allow", "deny"].sample }
    bib_fmt { ["BK", "CF", "MP", "MU", "MX", "SE", "VM"].sample }
    enum_chron { ["", "V.1"].sample }
    collection_code { ["MIU", "PU"].sample }

    trait :spm do
      bib_fmt { "BK" }
      enum_chron { "" }
    end

    trait :mpm do
      bib_fmt { "BK" }
      enum_chron { "V.#{rand(5).to_int}" }
    end

    trait :ser do
      bib_fmt { "SE" }
      enum_chron { "V.#{rand(200).to_int}" }
    end

    # The collection_code and billing_entity must "belong to" the same organization.
    # Not putting this in the main class, because this is only addressing wonky tests.
    after(:build) do |ht_item, context|
      query = {
        billing_entity: context.billing_entity,
        content_provider_cluster: context.billing_entity,
        responsible_entity: context.billing_entity
      }
      collection_codes = Services.holdings_db[:ht_collections][query]

      # If the collection_code does not belong to the billing_entity, make it.
      if !collection_codes.nil? && context.collection_code != collection_codes[:collection]
        context.collection_code = collection_codes[:collection]
      end
    end
  end
end
