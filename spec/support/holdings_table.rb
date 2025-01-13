require "services"

RSpec.shared_context "with holdings table" do
  before(:each) do
    Services.holdings_table.truncate
  end

  def insert_holding(holding)
    Services.holdings_table.insert(holding.to_hash)
  end
end
