# frozen_string_literal: true

require "settings"
require "concordance_validation/concordance"

class ConcordanceProcessing

  def validate(fin, fout)
    log = File.open("#{fout}.log", "w")
    fout = File.open(fout, "w")

    c = ConcordanceValidation::Concordance.new(fin)
    c.raw_to_resolved.each_key do |raw|
      next if c.raw_to_resolved[raw].count.zero?

      begin
        sub = c.compile_sub_graph(raw)
        c.detect_cycles(*sub)
      rescue => e
        log.puts e
        log.puts "Cycles:#{(sub[0].keys + sub[1].keys).flatten.uniq.join(", ")}"
        next
      end
      begin
        # checks for multiple terminal ocns
        _terminal = c.terminal_ocn(raw)
      rescue => e
        log.puts e
        next
      end

      fout.puts [raw, c.terminal_ocn(raw)].join("\t")
    end
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


   
    


