# print_holdings_redux


## Concordance Validation

Module and class to validate OCLC concordance files. 
Takes a tsv file (gzipped or not) and:
  * checks for correct format
  * checks for raw OCNs resolving to multiple "terminal" OCNs
  * checks for cycles

`nohup bundle exec ruby concordance_validation.rb 201912_concordance.txt.gz concordance.tsv &`

It makes no attempt at being performant or to limit its resource constraints, i.e. it likes memory.
