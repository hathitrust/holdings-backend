# frozen_string_literal: true

require "scrub/type_checker"
require "scrub/type_check_error"
require "spec_helper"

RSpec.describe Scrub::TypeChecker do
  include_context "with tables for holdings"
  let(:org) { "umich" }

  def make(new:, old: [])
    described_class.new(organization: org, new_types: new, old_types: old)
  end

  def validate(new:, old: [])
    make(new: new, old: old).validate
  end

  describe "#initialize" do
    it "initializes OK" do
      expect { make(new: ["spm"], old: ["spm"]) }.not_to raise_error
    end
    it "requires required fields" do
      expect { described_class.new }.to raise_error ArgumentError
    end
    it "sets new_types and old_types as given" do
      type_checker = make(new: ["spm"], old: ["spm", "mpm"])
      expect(type_checker.new_types).to match_array ["spm"]
      expect(type_checker.old_types).to match_array ["spm", "mpm"]
    end
    it "sets old_types to empty if none given and none in db" do
      type_checker = make(new: ["spm"])
      expect(type_checker.old_types).to match_array []
    end
    it "sets old_types to whatever distinct types are in the database for org" do
      types_in_db = ["spm", "mpm", "ser"]
      types_in_db.each do |type|
        load_test_data(build(:holding, organization: org, mono_multi_serial: type))
      end
      type_checker = make(new: ["spm"])
      expect(type_checker.old_types).to match_array types_in_db
    end
  end

  describe "#validate" do
    it "validates OK when new == old" do
      type_checker = make(new: ["spm"], old: ["spm"])
      expect { type_checker.validate }.not_to raise_error
    end
    it "validates OK when old is empty" do
      new = ["spm"]
      old = []
      type_checker = make(new: new, old: old)
      expect { type_checker.validate }.not_to raise_error
    end
    it "validates OK when new is a subset of old" do
      new = ["spm"]
      old = ["spm", "mpm", "ser"]
      type_checker = make(new: new, old: old)
      expect { type_checker.validate }.not_to raise_error
    end
    it "generates a message when validation fails" do
      type_checker = make(new: ["mix", "ser"], old: ["spm", "mpm", "ser"])

      expect { type_checker.validate }.to raise_error(Scrub::TypeCheckError, /There is a mismatch in item types\..+The diff is: mix\./)
    end
    it "refuses if we have mpm, spm, and ser loaded and member submits mon and ser or mix" do
      old = ["spm", "mpm", "ser"]
      expect { validate(new: ["mon"], old: old) }.to raise_error(Scrub::TypeCheckError)
      expect { validate(new: ["mon", "ser"], old: old) }.to raise_error(Scrub::TypeCheckError)
      expect { validate(new: ["mix"], old: old) }.to raise_error(Scrub::TypeCheckError)
    end
    it "refuses if we have mon and ser loaded and member submits mix or mpm/spm/ser" do
      old = ["mon", "ser"]
      expect { validate(new: ["mix"], old: old) }.to raise_error(Scrub::TypeCheckError)
      expect { validate(new: ["mpm"], old: old) }.to raise_error(Scrub::TypeCheckError)
    end
    it "refuses if we have mix loaded and member submits mon/ser or mpm/spm/ser" do
      old = ["mix"]
      expect { validate(new: ["mon", "ser"], old: old) }.to raise_error(Scrub::TypeCheckError)
      expect { validate(new: ["mpm", "spm", "ser"], old: old) }.to raise_error(Scrub::TypeCheckError)
    end
  end
end
