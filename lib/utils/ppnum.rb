# frozen_string_literal: true

# WHAT? Defining a global function? Yup.
#
# "Pretty print" a number into an underscore-delimited number
# right-space-padded out to the specifified width (default 0 indicating
# "no padding") and with the specified number of digits to the right
# of the decimal point (default again 0, meaning no decimal point at all)
#
# Example: ppnum(10111) => "10_111"
#          ppnum(1234.56) => 1_235
#          ppnum(10111.3456, 10, 1) => "  10_111.3"
#
# No attempt is made to deal gracefully with numbers that overrun the
# specified width
def ppnum(i, width = 0, decimals = 0)
  dec_str = if decimals.zero?
    ""
  else
    ".#{format("%.#{decimals}f", i).split(".").last}"
  end
  numstr = i.floor.to_s.reverse.split(/(...)/)
    .reject(&:empty?)
    .map(&:reverse)
    .reverse
    .join("_") + dec_str
  if width.zero?
    numstr
  else
    format "%#{width}s", numstr
  end
end
