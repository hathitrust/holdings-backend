# frozen_string_literal: true

require "spec_helper"
require "data_sources/ht_organizations"
require "timecop"

RSpec.describe DataSources::HTOrganizations do
  let(:mock_data) do
    {
      "example" => DataSources::HTOrganization.new(inst_id: "example", country_code: "xx",
        weight: 3.5, oclc_sym: "ZZZ")
    }
  end

  let(:ht_organizations) { described_class.new(mock_data) }

  let(:temp_organization) do
    DataSources::HTOrganization.new(inst_id: "temp", country_code: "zz", weight: 1.0)
  end
  let(:temp_non_member) do
    DataSources::HTOrganization.new(inst_id: "temp_non_member", country_code: "zz", weight: 1.0,
      status: false)
  end

  describe "#[]" do
    it "can fetch an institution" do
      expect(ht_organizations["example"].country_code).to eq("xx")
      expect(ht_organizations["example"].weight).to eq(3.5)
      expect(ht_organizations["example"].oclc_sym).to eq("ZZZ")
      expect(ht_organizations["example"].mapto_inst_id).to be("example")
    end

    it "raises a KeyError when institution has no data" do
      expect { ht_organizations["nonexistent"] }.to raise_exception(KeyError)
    end
  end

  describe "mapto" do
    let(:mock_data) do
      {
        "mapfrom1" => DataSources::HTOrganization.new(inst_id: "mapfrom1", mapto_inst_id: "mapto"),
        "mapfrom2" => DataSources::HTOrganization.new(inst_id: "mapfrom2", mapto_inst_id: "mapto")
      }
    end
    it "returns all institution ids that map to the given one" do
      expect(ht_organizations.mapto("mapto").map(&:inst_id)).to contain_exactly("mapfrom1", "mapfrom2")
    end
  end

  describe "#organizations" do
    it "returns all organizations as a hash" do
      expect(ht_organizations.organizations.keys).to contain_exactly("example")
    end
  end

  describe "#members" do
    it "returns all members with status.true? as a hash" do
      ht_organizations.add_temp(temp_non_member)
      expect(temp_non_member.status).to be false
      expect(ht_organizations.organizations.keys).to include("temp_non_member")
      expect(ht_organizations.members.keys).to contain_exactly("example")
    end
  end

  describe "#add_temp" do
    it "can add a temporary institution" do
      expect(ht_organizations.add_temp(temp_organization)).not_to be(nil)
    end

    it "can fetch a temporary institution" do
      ht_organizations.add_temp(temp_organization)

      expect(ht_organizations["temp"].country_code).to eq("zz")
    end
  end

  describe "db connection" do
    let(:ht_organizations) { described_class.new }

    include_context "with tables for holdings"

    it "can fetch data from the database" do
      expect(ht_organizations["umich"].country_code).to eq("us")
      expect(ht_organizations["umich"].weight).to eq(1.33)
      expect(ht_organizations["umich"].oclc_sym).to eq("EYM")
    end

    it "can fetch the full set of organizations" do
      expect(ht_organizations.organizations.size).to be > 10
    end

    it "does not persist temp members to the database/across instances" do
      ht_organizations.add_temp(temp_organization)

      expect(described_class.new.organizations.key?("temp")).to be false
    end
  end

  describe DataSources::HTOrganization do
    describe "#initialize" do
      it "raises an error if no inst_id" do
        expect { described_class.new(inst_id: nil) }.to raise_exception("Must have institution id")
      end

      it "raises an error if no weight" do
        expect { described_class.new(inst_id: "example", weight: -1) }.to \
          raise_exception("Weight must be between 0 and 10")
      end
    end
  end

  describe "cache" do
    it "refreshes ht_organizations" do
      Services.ht_db[:ht_billing_members].where(inst_id: "foo").delete
      Services.ht_db[:ht_institutions].where(inst_id: "foo").delete
      Services.register(:ht_organizations) { DataSources::HTOrganizations.new }

      expected_error = /No organization_info data for inst_id:foo/
      # Expect to not see foo initially.
      expect { Services.ht_organizations["foo"] }.to raise_error(KeyError, expected_error)

      # Insert it directly into DB but expect to not see it in the cache.
      Services.ht_db[:ht_billing_members].insert(
        inst_id: "foo",
        parent_inst_id: "foo",
        weight: 1.00,
        oclc_sym: "foo",
        marc21_sym: "foo",
        country_code: "fi",
        status: true
      )
      Services.ht_db[:ht_institutions].insert(
        inst_id: "foo",
        grin_instance: nil,
        name: nil,
        template: nil,
        domain: nil,
        us: false,
        mapto_inst_id: "foo",
        mapto_name: nil,
        enabled: false,
        entityID: nil,
        allowed_affiliations: nil,
        shib_authncontext_class: nil,
        emergency_status: nil
      )

      # Make sure we actually got them into the db.
      expect(Services.ht_db[:ht_billing_members].where(inst_id: "foo").count).to eq 1
      expect(Services.ht_db[:ht_institutions].where(inst_id: "foo").count).to eq 1

      # Reload the Services cache and expect to see the new organization.
      expect { Services.ht_organizations["foo"] }.not_to raise_error
      expect(Services.ht_organizations["foo"]).to be_a DataSources::HTOrganization
    ensure
      Services.ht_db[:ht_billing_members].where(inst_id: "foo").delete
      Services.ht_db[:ht_institutions].where(inst_id: "foo").delete
    end

    it "refreshes cache after an interval" do
      ht_orgs = described_class.new
      org = "emory"
      original_weight = ht_orgs[org].weight
      new_weight = original_weight * 2

      Services.ht_db[:ht_billing_members].where(inst_id: org).update(weight: new_weight)
      expect(ht_orgs[org].weight).to eq original_weight
      Timecop.travel(Time.now + described_class::CACHE_MAX_AGE_SECONDS + 1) do
        expect(ht_orgs[org].weight).to eq new_weight
      end
    ensure
      Services.ht_db[:ht_billing_members].where(inst_id: org).update(weight: original_weight)
    end
  end
end
