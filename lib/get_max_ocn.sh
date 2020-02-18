# Script that calls up oclc and asks for the current max ocn.
# Memoized so as to only call max once per day.

# Assumes a) that web service never dies/changes/moves,
# and     b) that it's safe to write these to /tmp/
# and     c) ownership/permissions for these tmp files are OK

epoch=`date +%s`;
memo_template="max_ocn_memoized"
memo_dir="/tmp"
too_old=86400 # one day in seconds

function make_curl_call {
    echo "Calling oclc..."
    curl -s "https://www.oclc.org/apps/oclc/wwg" |
	grep -Po '"oclcNumber":"\d+"' |
	grep -Po '\d+' > "$memo_dir/$memo_template"_"$epoch".txt;
    cat "$memo_dir/$memo_template"_"$epoch".txt;
}

# check cache
memoized=`ls -w1 $memo_dir/ | grep "$memo_template" | tail -1`;

if [ -z "$memoized" ]; then
    # no cache hit
    echo "No cache hit.";
    make_curl_call;
else
    # cache hit
    echo "Cache hit ($memoized), check age...";
    memoized_epoch=`echo "$memoized" | grep -Po '\d+'`;
    epoch_diff=`expr $epoch - $memoized_epoch`;
    echo "Age diff $epoch_diff seconds.";

    # check if cache hit is stale
    if [ "$epoch_diff" -gt "$too_old" ]; then
	# stale, remove & make fresh
	echo "Cache expired.";
	rm --verbose "$memo_dir/$memoized";
	make_curl_call;
    else
	# cache hit still fresh
	echo "Cache fresh.";
	cat "$memo_dir/$memoized";
    fi
fi
