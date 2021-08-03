#!/bin/bash
# MW Nov 2017.
# Attempting to automate the construction of the cost report so that it
# takes as little manual work as possible. Re-creates the whole cost
# history from scratch each time, and outputs 3 separate report files.
# Be aware that this will slurp up any cost report under <input_dir>
# so don't let experimental ones sit around when running this.

# Args:
# Takes a dir where the costreports are located as 1st arg
# and a dir where to put the outfiles           as 2nd arg.

# Usage:
# $ bash ./bin/cost_changes.sh <input_dir> <output_dir>

in_dir=$1
out_dir=$2
ymd=`date +'%Y-%m-%d'`;

totals_file="$out_dir/append_totals_$ymd.tsv";
diff_file="$out_dir/diff_totals_$ymd.tsv";
diffp_file="$out_dir/diff_percent_totals_$ymd.tsv";

# Get all current members.
member_list=`bundle exec ruby lib/ht_members.rb | tr '\n' '|'`;
keep_lines="^($member_list";
keep_lines+="_header)\t";

# Putting it all together.
all_reports=`find $in_dir -regex '.*/costreport_[0-9]+.tsv$' | sort -n | tr '\n' ' '`;

# Find all totals files and append them.
function append_totals () {
    perl ./bin/append_sheets.pl --f=0,-1 --header $all_reports;
}

# Compare sheet n with n+1 for diff over builds.
function diff_totals () {
    perl ./bin/append_sheets.pl --f=0,-1 --header --op='-' $all_reports;
}

# Compare sheet n with n+1 for diff% over builds.
function diff_percent_totals () {
    perl ./bin/append_sheets.pl --f=0,-1 --header --op='%' $all_reports;
}

# Header values are full file path. Shorten to just the date part.
function clean_header () {
    sed -r 's/[^\t]+?_([0-9]+).tsv/\1/g';
}

# Output reports.
append_totals       | clean_header | grep -P $keep_lines > $totals_file;
diff_totals         | clean_header | grep -P $keep_lines > $diff_file;
diff_percent_totals | clean_header | grep -P $keep_lines > $diffp_file;

echo "Wrote these files:";
echo $totals_file;
echo $diff_file;
echo $diffp_file;
