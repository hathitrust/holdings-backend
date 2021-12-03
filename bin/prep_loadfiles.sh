#!/bin/bash

# Temporary solution until we're using autoscrub.
# Takes HT003 files, sorts on OCN, adds UUID and splits into chunks.
# Number of chunks is set to 16, seems to be a good number.
# These chunks can then be fed into add_print_holdings.rb by parallell workers.

# Path to dir with all the HT003-files (and only those) that you want to load.
input_dir=$1

# Path to dir where the sorted, split, & uuid-enriched chunks get written.
output_dir=$2

# Check for required input/output dirs.
if [ -z "$input_dir" ]; then
    echo "Need input_dir as 1st arg."
    exit 1
elif [ -z "$output_dir" ]; then
    echo "Need output_dir as 2nd arg."
    exit 1
else
    echo "# Input from $input_dir and output to $output_dir"
fi

# Set up outputs.
mkdir -pv $output_dir
outfile_1="$output_dir/all_ht003.tsv"
outfile_2="$output_dir/all_ht003_sort.tsv"
chunk_count=16

# Cleanup from potential previous run.
rm -fv $outfile_1 $outfile_2

# Concat all input files into one file.
for file in `ls -w1 $input_dir/HT003_*.tsv`
do
    egrep -vh '^OCN' $file >> $outfile_1
done

# Sort concatenated file on OCN, add UUID
sort -s -n -k1,1 -T ./ $outfile_1 \
    | bundle exec ruby bin/add_uuid.rb > $outfile_2

# Split into chunks.
split -d --verbose --number=l/$chunk_count $outfile_2 "$output_dir/split_"

# Add .tsv extension to chunks.
for file in `ls -w1 $output_dir/split_* | grep -v '.tsv'`
do
    mv -v $file $file.tsv
done

# Remove intermediate files.
rm -v $outfile_1 $outfile_2

exit 0
