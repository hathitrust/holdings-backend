# Description:
# This script takes 2 oclc concordance files, one old and one new.
# Each is inflated, and records that say x->x are discarded.
# A diff is then calculated, such that the diff could transform the
# old file into the new file.

# Call thus, if assuming the old and new concordance files are in ../data::
# $ bash get_concordance_delta.sh
# ... or thus if the location is elsewhere:
# $ bash get_concordance_delta.sh <path_to_old> <path_to_new>

function isodate {
  date +'%Y-%m-%d %H:%M:%S';
}

function logmsg {
    echo "`isodate` $1"
}

data_dir="../data";
logmsg "started";

# Assume concordance files, old and new, are given as args, full path.
old_gz=$1;
new_gz=$2;

# If not given as args, get the 2 latest concordance files from data dir.
if [[ -z "$old_gz" || -z "$new_gz" ]]; then
    cd $data_dir;
    old_gz=`ls -d -1 $PWD/*_concordance.txt.gz | tail -2 | head -1`;
    new_gz=`ls -d -1 $PWD/*_concordance.txt.gz | tail -1`;
    cd -;
fi

echo "using $old_gz as old_file";
echo "using $new_gz as new_file";

logmsg "zcat + awk";

# Remove all lines that say x->x, we don't care about those.
zcat $old_gz |  awk -F'\t' '$1 != $2' > $data_dir/old.txt &
zcat $new_gz |  awk -F'\t' '$1 != $2' > $data_dir/new.txt &
wait; # running the 2 things above in parallel.

logmsg "diffing";

# straight up diff? nope.
perl mwSetDiff.pl $data_dir/old.txt $data_dir/new.txt > $data_dir/diff.txt;

logmsg "counting diff";

# Count how many </>
echo 'In/out:';
grep -Po '[<>]' $data_dir/diff.txt | sort | uniq -c

# Cleanup.
rm --verbose $data_dir/old.txt $data_dir/new.txt;

#####
logmsg "done";
