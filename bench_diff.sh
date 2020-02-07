# Checking if there are any speed gains in using threads.
for i in {1..10}
do
    time perl oclc_concordance/setDiff.pl data/old_3M.txt data/new_3M.txt          > /dev/null;
    time perl oclc_concordance/setDiff.pl data/old_3M.txt data/new_3M.txt --thread > /dev/null;
done
