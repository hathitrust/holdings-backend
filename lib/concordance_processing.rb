# frozen_string_literal: true

require "milemarker"
require "settings"
require "concordance_validation/concordance"
require "concordance_validation/delta"

class ConcordanceProcessing
  def validate(fin, fout)
    log = File.open("#{fout}.log", "w")
    fout = File.open(fout, "w")

    Services.logger.info "checking concordance file format..."
    ConcordanceValidation::Concordance.numbers_tab_numbers(fin)
    c = ConcordanceValidation::Concordance.new(fin)
    milemarker = Milemarker.new(batch_size: 10_000, name: "validate concordance")
    milemarker.logger = Services.logger
    c.db.prepare("SELECT variant FROM concordance").execute.each do |variant|
      variant = variant[0]
      sub = c.compile_sub_graph(variant)
      c.detect_cycles(*sub)
      # checks for multiple canonical ocns
      _canonical = c.canonical_ocn(variant)
      fout.puts [variant, c.canonical_ocn(variant)].join("\t")
      milemarker.increment_and_log_batch_line
      Thread.pass
    rescue OCNCycleError, MultipleOCNError => e
      log.puts e
      log.flush
      next
    end
    log.close
    fout.close
    milemarker.log_final_line
  end

  # Compute deltas of new concordance with pre-existing validated concordance.
  def delta(fin_old, fin_new)
    conc_dir = Settings.concordance_path

    Services.logger.info("Diffing #{fin_old} and #{fin_new}")

    # compute delta
    delta = ConcordanceValidation::Delta.new(fin_old, fin_new)
    delta.run

    Services.logger.info("Concordance adds and deletes waiting in #{conc_dir}/diffs")
  end
end
