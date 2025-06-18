#!/bin/bash
# MW Nov 2017, updated Aug 2021.
# Attempting to automate the construction of the cost report so that it
# takes as little manual work as possible. Re-creates the whole cost
# history from scratch each time, and outputs 4 separate report files.
# Be aware that this will slurp up any cost report under <input_dir>
# so don't let experimental ones sit around when running this.

# Args:
# Takes a dir where the costreports are located as 1st arg,
# and a dir where to put the outfiles           as 2nd arg.

# Usage:
# $ bash ./bin/cost_changes.sh <input_dir> <output_dir>

in_dir=$1;
out_dir=$2;
mkdir -p $out_dir;
ymd=`date +'%Y-%m-%d'`;

# Set up output files.
totals_file="$out_dir/append_totals_$ymd.tsv";
diff_file="$out_dir/diff_totals_$ymd.tsv";
diffp_file="$out_dir/diff_percent_totals_$ymd.tsv";
hilites_file="$out_dir/hilites_$ymd.tsv";

# Get all current members.
member_list=`bundle exec ruby bin/phctl.rb members | grep -v 'hathitrust' | tr '\n' '|'`;
keep_lines="^($member_list";
keep_lines+="_header|member_id)\t";

# Get all reports (recursively) from $in_dir
all_reports=`find $in_dir -regex '.*/cost_?report_[0-9]+.tsv$' | sort -n | tr '\n' ' '`;

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

# The last column from the other 3 output files.
function hilites () {
    perl ./bin/append_sheets.pl --f=0,-1 $totals_file $diff_file $diffp_file | grep -v '_header';
}

# Header values are full file path. Shorten to just the date part.
function clean_header () {
    sed -r 's/[^\t]+?_([0-9]+).tsv/\1/g';
}

# Output reports.
append_totals       | clean_header | grep -P $keep_lines > $totals_file;
diff_totals         | clean_header | grep -P $keep_lines > $diff_file;
diff_percent_totals | clean_header | grep -P $keep_lines > $diffp_file;
hilites             |                grep -P $keep_lines > $hilites_file;

echo "Wrote these files:";
echo $totals_file;
echo $diff_file;
echo $diffp_file;
echo $hilites_file;

# Special handling until the budget is set in 2025:
prev_budget_report=`echo "$all_reports" | grep -Po '\S+costreport_20240801.tsv'`
last_report=`echo "$all_reports" | awk '{print $NF}'`
echo "Special diff between $prev_budget_report and $last_report to $out_dir/hilites_budget_diff_$ymd.tsv and $out_dir/hilites_budget_pct_diff_$ymd.tsv"
hilites_budget_diff="/tmp/hilites_budget_diff_$ymd.tsv"
hilites_budget_diff_pct="/tmp/hilites_budget_pct_diff_$ymd.tsv"
hilites_budget_diffs="$out_dir/hilites_budget_diffs_$ymd.tsv"
perl ./bin/append_sheets.pl --f=0,-1 --header --op='-' $prev_budget_report $last_report | grep -P $keep_lines > "$hilites_budget_diff"
perl ./bin/append_sheets.pl --f=0,-1 --header --op='%' $prev_budget_report $last_report | grep -P $keep_lines > "$hilites_budget_diff_pct"
perl ./bin/append_sheets.pl --f=0,-1 --header $prev_budget_report $last_report $hilites_budget_diff $hilites_budget_diff_pct | grep -P $keep_lines > "$out_dir/hilites_budget_diffs_$ymd.tsv"
rm "$hilites_budget_diff" "$hilites_budget_diff_pct"
