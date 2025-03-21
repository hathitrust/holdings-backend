# frozen_string_literal: true

require "date"
require "faker"
require "loader/loaded_file"

FactoryBot.define do
  factory :loaded_file, class: "Loader::LoadedFile" do
    to_create(&:save)

    filename { Faker::File.file_name(ext: ["tsv", "json"].sample) }
    produced { Faker::Date.between(from: Date.today - 7, to: Date.today - 365) }
    loaded { Faker::Time.backward(days: 5) }
    source { ["hathitrust", "oclc", "umich"].sample }
    type { ["holdings", "concordance", "hathifile"].sample }
  end
end
