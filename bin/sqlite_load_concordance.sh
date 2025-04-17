#!/bin/bash

db_file=$1
deduped_concordance_file=$2
sqlite3 "$db_file" << EOF
.mode tabs
.import "$deduped_concordance_file" "concordance"
EOF
