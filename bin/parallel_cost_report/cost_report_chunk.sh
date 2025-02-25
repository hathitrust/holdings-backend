# dump hathifiles
# fields: htid, bib_num, rights_code, access, bib_fmt, descxription, collection_code, oclc
# order by bib_num

# or whatever
export SOLR_URL="http://localhost:8983/solr/catalog/"

mkdir solr_dump

bundle exec ruby solr_records_for_cost_report.rb > all_records.ndj

split -l 50000 solr_dump/all_records.ndj records_

parallel ./phctl.sh frequency-table ::: solr_dump/records_*
