#!/bin/bash

# Description:
# This script takes 2 oclc concordance files, one old and one new.
# Each is inflated, and records that say x->x are discarded.
# A diff is then calculated, such that the diff could transform the
# old file into the new file.

# Call thus, if assuming the old and new concordance files are in ../data::
# $ bash comm_concordance_delta.sh
# ... or thus if the location is elsewhere:
# $ bash comm_concordance_delta.sh <path_to_old> <path_to_new>


function isodate {
  date +'%Y-%m-%d %H:%M:%S';
}

function logmsg {
    echo "`isodate` $1";
}

logmsg "started";

script_dir=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$script_dir" 

data_dir="../data";

# Assume concordance files, old and new, are given as args, full path.
old_gz=$1;
new_gz=$2;

# If not given as args, get the 2 latest concordance files from data dir.
if [[ -z "$old_gz" || -z "$new_gz" ]]; then
    cd $data_dir;
    old_gz=`ls -d -1 $PWD/*_concordance.txt.gz | tail -2 | head -1`;
    new_gz=`ls -d -1 $PWD/*_concordance.txt.gz | tail -1`;
    cd -;

    # OK did we actually get any files?
    if [[ -z "$old_gz" || -z "$new_gz" ]]; then
	echo "Could not find 2 concordance files in $data_dir";
	exit 1;
    fi
fi

echo "using $old_gz as old_file";
echo "using $new_gz as new_file";

logmsg "zcat + awk";

# Prune lines that say x->x, we don't care about those.
# This might become part of the validation step that happens before
# this, so it might soon be obsolete and can then be excised.
# Also sort now in preparation for comm -3 below.
zcat -f $old_gz | awk -F'\t' '$1 != $2' | sort > $data_dir/old_pruned.txt &
zcat -f $new_gz | awk -F'\t' '$1 != $2' | sort > $data_dir/new_pruned.txt &
wait; # running the 2 things above in parallel.

output="$data_dir/comm_diff.txt"
logmsg "diffing, writing results to $output";

# Get the lines unique to either file.
# The awk business is just to get it into
# > a b
# < c d
# format which I think is neater..
#comm -3 $data_dir/old_pruned.txt $data_dir/new_pruned.txt | awk -F'\t' '{if ($1 == ""){ print ">\t" $2 "\t" $3 }else{ print "<\t" $1 "\t" $2} }' > $output;
comm -3 $data_dir/old_pruned.txt $data_dir/new_pruned.txt | awk -F'\t' "{if (\$1 == \"\"){ print \$2 \"\t\" \$3 > \"$output.adds\" }else{ print \$1 \"\t\" \$2 > \"$output.deletes\"} }";

# Clean up intermediate files.
rm $data_dir/old_pruned.txt $data_dir/new_pruned.txt;

#####
logmsg "done";
