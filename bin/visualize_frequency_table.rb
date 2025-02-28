require "json"
require "frequency_table"

# Usage:
# 
# mkdir freqtable-graphs
# cd freqtable-graphs
# bundle exec ruby bin/visualize_frequency_table.rb ../input-frequency-table.json
# gnuplot < gnuplot-commands.txt
#
# Output is one data file and one PNG file per contributor & format.

freqtable = FrequencyTable.new(data: File.read(ARGV[0]))

File.open("gnuplot-commands.txt","w") do |gnuplot|

  gnuplot.puts <<~EOT
    set term pngcairo size 2560,800
    set boxwidth 0.5
    set style fill solid
    set xtics 5
  EOT

  freqtable.each do |org, formats|
    formats.each do |format, frequencies|
      key = "#{org}-#{format}"
      File.open("#{key}.dat","w") do |fh|
        frequencies.each do |freq, value|
          fh.puts [freq, value].join("\t")
        end
      end
      gnuplot.puts("set output \"#{key}.png\"")
      gnuplot.puts("plot \"#{key}.dat\" using 1:2 with boxes")
      gnuplot.puts
    end
  end

end
