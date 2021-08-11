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

## K8s Cronjob
`kubectl create -f cron_job.yaml`

Runs `validate_and_delta.rb` daily at 2300UTC, which is presumed EOD for the parties involved.
`validate_and_delta.rb` checks the concordance directory for new un-validated concordance files, validates them and diffs with a previous concordance.
Posts a message to the slack channel so we know there is an update to be loaded. 
It does NOT attempt to update the concordance as it may conflict with reporting operations. This would require more complicated orchestration of jobs.

## One command validation and delta
`bin/validate_and_delta.sh`

It runs a job that will validate un-validated concordances found in `CONC_HOME/raw` then diff it with a previous validated concordance. The diffs get put into `CONC_HOME/diffs`.
