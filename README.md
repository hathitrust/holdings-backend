# oclc_concordance_validator


## Concordance Validation

Module and class to validate OCLC concordance files. 
Takes a tsv file (gzipped or not) and:
  * checks for correct format
  * checks for raw OCNs resolving to multiple "terminal" OCNs
  * checks for cycles

`nohup bundle exec ruby concordance_validation.rb 201912_concordance.txt.gz concordance.tsv &`

It makes no attempt at being performant or to limit its resource constraints, i.e. it likes memory.

## Delta Generation

Code for generating a delta file based on an old and a new concordance.

`cd get_delta`

`bash comm_concordance_delta.sh <old_concordance> <new_concordance>`

Output written to data/comm_diff.txt
