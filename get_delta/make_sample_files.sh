# Get some random-transliterated test data from 2 .gz files,
# for purposes of doing quick tests of delta generation.
# Usage:
# $ bash make_sample_files.sh <old_file> <new_file>

# Turn 0..9 into random range, for use in tr later.
rand_int_rng=`perl -e "print join('', (sort {rand() <=> 0.5} (0..9)))"`;

# Put stuff here.
data_dir='../data';

old_fn=$1;
new_fn=$2;

function get_sample_translit {
    fn=$1;
    old_new=$2;

    zcat -f $fn |
	head -100000 |
	awk -F'\t' '$1 != $2' |
	tr '[0-9]' "[$rand_int_rng]" |
	sort > $data_dir/${old_new}_head_sample_obfusc.txt    
}

# Transliterate old and new with (the same) random letters.
get_sample_translit $old_fn 'old';
get_sample_translit $new_fn 'new';

comm -3 $data_dir/old_head_sample_obfusc.txt $data_dir/new_head_sample_obfusc.txt
