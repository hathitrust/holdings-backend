# frozen_string_literal: true

module SharedPrint
  class Phases
    PHASE_0 = 0 # Default, has no associated date
    PHASE_1 = 1
    PHASE_2 = 2
    PHASE_3 = 3
    PHASE_1_DATE = "2017-09-30 00:00:00 UTC"
    PHASE_2_DATE = "2019-02-28 00:00:00 UTC"
    PHASE_3_DATE = "2023-01-31 00:00:00 UTC"

    # Call .invert on this if you ever need reverse map
    def self.phase_to_date
      {
        PHASE_1 => PHASE_1_DATE,
        PHASE_2 => PHASE_2_DATE,
        PHASE_3 => PHASE_3_DATE
      }
    end

    def self.list
      [PHASE_0, PHASE_1, PHASE_2, PHASE_3]
    end
  end
end
