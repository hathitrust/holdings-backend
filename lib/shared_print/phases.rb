# frozen_string_literal: true

module SharedPrint
  class Phases
    PHASE_1_DATE = "2017-09-30"
    PHASE_2_DATE = "2019-02-28"
    PHASE_3_DATE = "2023-01-31"

    # Call .invert on this if you ever need reverse map
    def self.phase_to_date
      {
        1 => PHASE_1_DATE,
        2 => PHASE_2_DATE,
        3 => PHASE_3_DATE
      }
    end
  end
end
