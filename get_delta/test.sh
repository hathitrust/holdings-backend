# Basic tests for comm_concordance_delta.sh.
# Run thus:
# $ bash test.sh

data_dir="../data";

function beep {
    echo -ne '\007';
}

function test_pass_fail {
    if [ "$1" = "$2" ]; then
	echo "Test pass";
    else
	echo "Test fail";
	beep;
    fi
}

function run_diff {
    bash comm_concordance_delta.sh $1 $2 > /dev/null;
}

# Test 1, compare file 1 against itself should make an empty diff.
run_diff $data_dir/delta_test_new.tsv $data_dir/delta_test_new.tsv;
wc -l $data_dir/comm_diff.txt > test.log;
line_count_res=`egrep -c '^[<]' $data_dir/comm_diff.txt`;
test_pass_fail 0 $line_count_res;

# Test 2, compare file 1 against empty file, diff should equal file 1
line_count_key=`wc -l $data_dir/delta_test_new.tsv | grep -Po '^\d+'`;
run_diff $data_dir/delta_test_new.tsv /dev/null;
# The number of <'s should equal number of lines in file 1
line_count_res=`egrep -c '^[<]' $data_dir/comm_diff.txt`;
test_pass_fail $line_count_key $line_count_res;

# Test 3, compare empty file against file 2, diff should equal file 2
line_count_key=`wc -l $data_dir/delta_test_new.tsv | grep -Po '^\d+'`;
run_diff /dev/null $data_dir/delta_test_new.tsv;
# The number of >'s should equal number of lines in file 2
line_count_res=`egrep -c '^[>]' $data_dir/comm_diff.txt`;
test_pass_fail $line_count_key $line_count_res;

# Test 4, compare 2 empty files, diff should be empty
run_diff /dev/null /dev/null;
line_count_res=`grep -c . $data_dir/comm_diff.txt`;
test_pass_fail 0 $line_count_res;

# Test 5, enough mucking about, actual diff between 2 "real" files
run_diff $data_dir/delta_test_old.tsv $data_dir/delta_test_new.tsv;
diff_add=`grep -c '^>' $data_dir/comm_diff.txt`;
diff_del=`grep -c '^<' $data_dir/comm_diff.txt`;
test_pass_fail 5 $diff_add;
test_pass_fail 4 $diff_del;

# Test 6, same as test 5 but flipped file order
run_diff $data_dir/delta_test_new.tsv $data_dir/delta_test_old.tsv;
diff_add=`grep -c '^>' $data_dir/comm_diff.txt`;
diff_del=`grep -c '^<' $data_dir/comm_diff.txt`;
test_pass_fail 4 $diff_add;
test_pass_fail 5 $diff_del;
