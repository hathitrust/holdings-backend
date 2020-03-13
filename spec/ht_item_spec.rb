# frozen_string_literal: true

require "ht_item"
require "cluster"

RSpec.describe HtItem do
  let(:ocn_rand) { rand(1_000_000).to_i }
  let(:item_id_rand) { rand(1_000_000).to_s }
  let(:ht_bib_key_rand) { rand(1_000_000).to_i }
  let(:htitem_hash) do
    { ocns:              [ocn_rand],
      item_id:      item_id_rand,
      ht_bib_key:          ht_bib_key_rand,
       }
  end

  it "can be created" do
    expect(described_class.new(htitem_hash)).to be_a(described_class)
  end

end

