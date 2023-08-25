# frozen_string_literal: true

require "services"
require "reports/oclc_registration"

module Reports
  # Runs a report for an organization, outputting all of their Phase 3
  # shared print commitments in an OCLC Registration-like format.
  # Based on, and uses similar plumbing as, Reports::OCLCRegistration
  # Usage:
  # rep = Reports::Phase3OCLCRegistration.new(org)
  # rep.run
  # puts "output written to #{rep.output_file}"
  class Phase3OCLCRegistration < Reports::OCLCRegistration
    def output_path
      # Set up path for output
      date = Time.new.strftime("%Y%m%d")
      File.join(@outd, "oclc_registration_phase3_#{@organization}_#{date}.tsv")
    end

    def finder
      SharedPrint::Finder.new(organization: [@organization], phase: [3])
    end

    # Generate report header:
    # * OCLC - submitted by member during registration as local_oclc
    # * LSN - submitted by member during registration as local_id
    # * Barcode - Blank (HT does not have)
    # * InstitutionSymbol_852$a - submitted by member during registration as oclc_symbol
    # * HoldingLibrary_852$b - Blank (HT does not have)
    # * CollectionID - Provided by member to HT after creating Collection Profile and kept in
    #   a configuration file that maps OCLC symbols to collection ID
    # * ActionNote_583$a - Always "committed to retain"
    # * ActionDate_583$c - For Phase 3 use 20230131
    # * ExpirationDate_583$d - Always "20421231"
    # * MethodofAction_583$i - Always "ivolume-level"
    # * Status_583$l - Always "condition reviewed"
    # * PublicNote_583$z - Only included for P3 and submitted by member during registration
    #   as "retention condition" Value can only be EXCELLENT or ACCEPTABLE.
    # * ProgramName_583$f - Blank (HT does not have)
    # * MaterialsSpecified_583$3 - Blank (HT does not have)
    def hed
      [
        "OCLC",
        "LSN",
        "Barcode",
        "InstitutionSymbol_852$a",
        "HoldingLibrary_852$b",
        "CollectionID",
        "ActionNote_583$a",
        "ActionDate_583$c",
        "ExpirationDate_583$d",
        "MethodofAction_583$i",
        "Status_583$l",
        "PublicNote_583$z",
        "ProgramName_583$f",
        "MaterialsSpecified_583$3"
      ].join("\t")
    end

    # Format a commitment for the report.
    def fmt(com)
      [
        com.ocn, # OCLC
        com.local_id, # LSN
        "", # Barcode
        com.oclc_sym, # InstitutionSymbol_852$a
        "", # HoldingLibrary_852$b
        collection_id(com.oclc_sym), # CollectionID
        "committed to retain", # ActionNote_583$a
        "20230131", # ActionDate_583$c
        "20421231", # ExpirationDate_583$d
        "ivolume-level", # MethodofAction_583$i
        "condition reviewed", # Status_583$l
        com.retention_condition, # PublicNote_583$z
        "", # ProgramName_583$f
        "" # MaterialsSpecified_583$3
      ].join("\t")
    end
  end
end
