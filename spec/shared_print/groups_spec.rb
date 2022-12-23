require "shared_print/groups"

RSpec.describe SharedPrint::Groups do
  let(:g) { described_class.new }
  describe "#group_to_orgs" do
    it "given a group name it returns the member organizations" do
      expect(g.group_to_orgs("recap")).to eq ["columbia", "harvard", "nypl", "princeton"]
    end
    it "given a group name that does not exist it returns nil" do
      expect(g.group_to_orgs("foo")).to be_nil
    end
  end
  describe "#org_to_groups" do
    it "given an organization name it returns the organization(s) it is a member of" do
      expect(g.org_to_groups("princeton")).to eq ["recap", "ivyplus"]
    end
    it "given an organization that does not exist it returns nil" do
      expect(g.org_to_groups("foo")).to be_nil
    end
  end
end
