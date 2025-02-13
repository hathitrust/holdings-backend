# dump hathifiles
# fields: htid, bib_num, rights_code, access, bib_fmt, descxription, collection_code, oclc
# order by bib_num

mkdir hf_dump

bin/mariadb.sh -e "SELECT htid, bib_num, rights_code, access, bib_fmt, description, collection_code, oclc FROM hf WHERE rights_code IN ('ic','und','op','nobody','pd-pvt') ORDER BY bib_num;" > hf_dump/hf_dump

# chunk

split -l 100000 hf_dump/hf_dump

# parallel bundle exec ruby bin/generate_freq_table.rb ::: hf_dump/hf_dump_*
