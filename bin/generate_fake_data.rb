#!env ruby

require "factory_bot"
require "faker"
require_relative "../spec/fixtures/organizations"
require_relative "../spec/fixtures/collections"

FactoryBot.find_definitions

Services.register(:ht_organizations) { mock_organizations }
Services.register(:ht_collections) { mock_collections }

OUTDIR = "/usr/src/app/testdata"
MAX_OCN = 100000

def random_year
  Faker::Date.between(from: Date.parse("1850-01-01"), to: Date.today).year
end

def warn_exists(outfile)
  if(File.exist?(outfile))
    puts "#{outfile} already exists, not creating"
    true
  else
    false
  end
end


# For now, only single-part monographs

def generate_holdings(count = 50000, inst = "umich", date = Date.parse("2020-01-01"))
  # holdings
  FileUtils.mkdir_p(OUTDIR)
  outfile = File.join(OUTDIR, "umich_fake_holdings.ndj")
  return if warn_exists(outfile)
  File.open(outfile, "w") do |out|
    count.times do
      holding = FactoryBot.build(:holding,
        organization: "umich",
        mono_multi_serial: "mon",
        ocn: rand(MAX_OCN),
        date_received: date)
      out.puts(holding.as_document.except("_id").to_json)
    end
  end
end

def htitem_fields(max_ocn: MAX_OCN)
  htitem = FactoryBot.build(:ht_item, ocns: [rand(max_ocn).to_s])
  collection = Services.ht_collections[["PU", "MIU", "KEIO", "UCM"].sample]
  [
    htitem.item_id,
    htitem.access,
    htitem.rights,
    htitem.ht_bib_key,
    "", # description (enumchron),
    collection.collection, # source (usually collection code?),
    rand(1000000).to_s, # source_bib_num,
    htitem.ocns.join(","),
    Faker::Barcode.isbn,
    "", # issn
    "", # lccn,
    Faker::Book.title,
    "#{Faker::Book.publisher}, [#{random_year}]", # imprint
    "bib", # rights_reason_code,
    Faker::Time.between(from: "2008-01-01", to: Date.today).strftime("%F %T"), # rights_timestamp
    ["1", "0"].sample, # us_gov_doc_flag,
    random_year,
    ["", "xxu", "miu", "fr", "mx", "xx"].sample, # pub place - https://www.loc.gov/marc/countries/countries_code.html
    ["eng", "ita", "hin", "heb"].sample, # language - https://www.loc.gov/marc/languages/language_code.html
    htitem.bib_fmt,
    collection.collection, # collection code
    collection.content_provider_cluster, # content_provider_code,
    collection.responsible_entity, # responsible_entity_code,
    ["google", "archive", "umich"].sample, # digitization_agent_code,
    ["open", "google"].sample, # access_profile_code,
    "#{Faker::Name.last_name}, #{Faker::Name.first_name}." # author
  ]
end

def generate_htitems(count = 20000)
  # htitems
  outfile = File.join(OUTDIR, "htitems_fake.tsv")
  return if warn_exists(outfile)
  File.open(outfile, "w") do |out|
    count.times do
      out.puts(htitem_fields(max_ocn: MAX_OCN).join("\t"))
    end
  end
end

def generate_ocn_resolutions(max_ocn = MAX_OCN, percent_deprecated = 0.10)
  # Generates resolutions for a random set of OCNs up to max_ocn.
  # In this data generator to ensure valid data, OCNs always resolve to an OCN
  # greater than themselves.
  outfile = File.join(OUTDIR, "ocns_fake.tsv")
  return if warn_exists(outfile)
  File.open(File.join(OUTDIR, "ocns_fake.tsv"), "w") do |out|
    1.upto(max_ocn) do |ocn|
      if rand < percent_deprecated
        out.puts([ocn, ocn + rand(max_ocn - ocn)].join("\t"))
      end
    end
  end
end

generate_holdings
generate_htitems
generate_ocn_resolutions

# to do: commitments
