# Basic tests for comm_concordance_delta.sh.
# Run thus:
# $ bash test.sh

data_dir="../data";

function test_pass_fail {
    echo -ne "$1:\t";
    if [ "$2" = "$3" ]; then
	echo "Test pass";
    else
	echo "Test fail (expected $1, got $2)";
    fi
}

function test_nonexistent {
  echo -ne "$1:\t";
  if [[ -e "$2" ]]; then
    echo "Test fail (file $2 shouldn't exist)";
  else
    echo "Test pass"
  fi
}

function run_diff {
  rm $data_dir/comm_diff.txt.adds
  rm $data_dir/comm_diff.txt.deletes
    bash comm_concordance_delta.sh $1 $2 > /dev/null;
}

# Test 1, compare file 1 against itself should make an empty diff.
run_diff $data_dir/delta_test_new.tsv $data_dir/delta_test_new.tsv;
test_nonexistent "same vs same (adds)" 0 "$data_dir/comm_diff.txt.adds"
test_nonexistent "same vs same (deletes)" 0 "$data_dir/comm_diff.txt.deletes"

# Test 2, compare file 1 against empty file, diff should equal file 1
line_count_key=`wc -l $data_dir/delta_test_new.tsv | grep -Po '^\d+'`;
run_diff $data_dir/delta_test_new.tsv /dev/null;
# The number of <'s should equal number of lines in file 1
line_count_res=`wc -l $data_dir/comm_diff.txt.deletes`;
test_pass_fail "file vs null (deletes)" $line_count_key $line_count_res;
test_nonexistent "file vs null (adds)" "$data_dir/comm_diff.txt.adds"

# Test 3, compare empty file against file 2, diff should equal file 2
line_count_key=`wc -l $data_dir/delta_test_new.tsv | grep -Po '^\d+'`;
run_diff /dev/null $data_dir/delta_test_new.tsv;
# The number of >'s should equal number of lines in file 2
line_count_res=`wc -l $data_dir/comm_diff.txt.adds`;
test_pass_fail "null vs file (adds)" $line_count_key $line_count_res;
test_nonexistent "null vs file (deletes)" "$data_dir/comm_diff.txt.deletes"

# Test 4, compare 2 empty files, diff should be empty
run_diff /dev/null /dev/null;
test_nonexistent "null vs null (adds)" "$data_dir/comm_diff.txt.adds"
test_nonexistent "null vs null (deletes)" "$data_dir/comm_diff.txt.deletes"

# Test 5, enough mucking about, actual diff between 2 "real" files
run_diff $data_dir/delta_test_old.tsv $data_dir/delta_test_new.tsv;
diff_add=`wc -l $data_dir/comm_diff.txt.adds`;
diff_del=`wc -l $data_dir/comm_diff.txt.deletes`;
test_pass_fail "old vs new add" 5 $diff_add;
test_pass_fail "old vs new del" 4 $diff_del;

# Test 6, same as test 5 but flipped file order
run_diff $data_dir/delta_test_new.tsv $data_dir/delta_test_old.tsv;
diff_add=`wc -l $data_dir/comm_diff.txt.adds`;
diff_del=`wc -l $data_dir/comm_diff.txt.deletes`;
test_pass_fail "new vs old add" 4 $diff_add;
test_pass_fail "new vs old del" 5 $diff_del;
