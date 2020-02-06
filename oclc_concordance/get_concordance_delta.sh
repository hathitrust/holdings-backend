function isodate {
  date +'%Y-%m-%d %H:%M:%S';
}

function logmsg {
    echo "`isodate` $1"
}

data_dir="../data";
logmsg "started";

# Assume concordance files, old and new, are given as args
old_gz=$1;
new_gz=$2;

# If not given as args, get the 2 latest concordance files from data dir.
if [[ -z "$old_gz" || -z "$new_gz" ]]; then
    cd $data_dir;
    old_gz=`ls  -d -1 $PWD/{*,.*} | tail -2 | head -1`;
    new_gz=`ls  -d -1 $PWD/{*,.*} | tail -1`;
    cd -;
fi

echo "using $old_gz as old_file";
echo "using $new_gz as new_file";

logmsg "zcat + awk";

# Remove all lines that say a->a, we don't care about those.
zcat $old_gz |  awk -F'\t' '$1 != $2' > $data_dir/old.txt &
zcat $new_gz |  awk -F'\t' '$1 != $2' > $data_dir/new.txt &
wait; # running the 2 things above in parallel.

logmsg "diffing";

# straight up diff?
perl mwSetDiff.pl $data_dir/old.txt $data_dir/new.txt > $data_dir/diff.txt;

logmsg "counting diff";

# Count how many </>
echo 'In/out:';
grep -Po '[<>]' $data_dir/diff.txt | sort | uniq -c

# Cleanup.
# rm --verbose old.txt new.txt;

#####
logmsg "done";
