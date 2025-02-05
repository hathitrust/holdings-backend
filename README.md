# Print Holdings persistent data store



![Build Status](https://github.com/hathitrust/holdings-backend/workflows/Docker%20Build/badge.svg)


## Prerequisites / Setup

* [Docker](https://docs.docker.com/install/)
* [Docker Compose](https://docs.docker.com/compose/install/)

```bash
docker compose build
docker compose run dev bundle install
docker compose run dev bin/reset_database.sh
```

## Running the tests

`docker compose run --rm test`

## Clearing out/resetting the data
For resetting everything (cleaning up containers & their persistent volumes):

```bash
# Clear it out
docker compose down # to stop services
docker volume rm holdings-backend_data_db # to clear out the development database
docker volume rm holdings-backend_gem_cache # to clear out gems

# Initialize the database
docker compose run dev bin/reset_database.sh
```

## Generating and loading fake data

This will generate a synthetic OCLC concordance, HT items, and holdings for a
single institution, and load it:

```bash
bash bin/load_test_data.sh
```

## Loading data

The Holdings data store is derived from three sources:
  * The OCLC concordance file
  * The Hathifiles
  * The "scrubbed" print holdings submissions from HT partners
  
Note that any file you're loading needs to be under the repository 
root (e.g., `holdings-backend` if you haven't renamed it for some reason).
This directory is mounted in the docker container, so anything under
it will also be available in the docker container. Files elsewhere on 
your host computer will *not* be reachable.

For all files, they will be batched by OCN. It is not required that incoming
files be sorted by OCN but they will likely load substantially faster if they
are and there are a lot of things with a particular OCN.

Files:
* Must be located under the repository root
* Can be gzipped or not -- the scripts will figure it out

Script command cheat sheet:
* `docker compose run --rm dev bundle exec bin/phctl load ht_items <filepath>`
* `docker compose run --rm dev bundle exec bin/add_print_holdings.rb
 <filepath>` (full file)
* `docker compose run --rm dev bundle exec bin/add_print_holdings.rb -u
 <filepath>` (update file)


### OCLC Concordance file 

The _oclc concordance file_ is a single file with two columns, each line
representing a pair of OCLC numbers that should be treated as equivalent.

There are ≈ 60M rows in this file. 

Concordance files can be downloaded from OCLC's website. See confluence for details.

1. Validate, e.g. 
  `run_generic_job.sh conc-val bundle exec bin/phctl.rb concordance validate /htprep/holdings/concordance/raw/202205_concordance.txt.gz /htprep/holdings/concordance/validated/202205_concordance_validated.tsv`

2. Compute deltas, e.g. 
  `run_generic_job.sh conc-delta bundle exec bin/phctl.rb concordance delta /htprep/holdings/concordance/validated/202205_concordance_validated.tsv /htprep/holdings/concordance/validated/202112_concordance_validated.tsv.gz`

3. Load deltas, e.g.
  `run_generic_job.sh load-conc bundle exec bin/phctl.rb load concordance 2022-05`
  
### Loading the HathiFiles

The _hathifiles_ come in both monthly "full-file" and daily "changes"
versions. Each line represents a single Hathitrust item/volume,
although some columns contain "record-level" data that is just repeated
for each item line. See the 
[Hathifiles file format specification](https://www.hathitrust.org/hathifiles_description)
for more info if you're interested.

To load a Hathifile (either a full file or an update) in development:
  * Grab the file from [the Hathifiles webpage](https://www.hathitrust.org/hathifiles)
  or directly from `/htapps/www/sites/www.hathitrust.org/files/hathifiles`
  * `docker compose run --rm dev bundle exec bin/phctl.rb load ht_items <filepath>`
  where the components are exactly as for the OCLC concordance file.

### Loading (scrubbed) print holdings

Print holdings are provided by each partner as a set of three files 
(for single-volume monographs, multi-volume monographs, and serials)
that describe their own holdings, keyed on OCLC number, with one line for
each copy they own (so, there might be identical lines representing multiple
copies of the same item). 

These raw files are "scrubbed" and verified, resulting in scrubbed files.

To load a scrubbed file in development:
  * Get the file(s) you want from `/htapps/mwarin.babel/phdb_scripts/data/loadfiles/`
  * Add UUIDs for tracking whether the individual line has been processed: `bin ruby/add_uuid.rb infile > outfile`
  * `docker compose run --rm dev bundle exec bin/add_print_holdings.rb outfile`

## K8s Cronjob
`kubectl create -f cron_job.yaml`

Runs `validate_and_delta.rb` daily at 2300UTC, which is presumed EOD for the parties involved.
`validate_and_delta.rb` checks the concordance directory for new un-validated concordance files, validates them and diffs with a previous concordance.
Posts a message to the slack channel so we know there is an update to be loaded. 
It does NOT attempt to update the concordance as it may conflict with reporting operations. This would require more complicated orchestration of jobs.

## Other Actions

### Delete Holdings

`bin/holdings_deleter.rb` can delete a set of holdings which matches the given criteria.
Critera are given on the commandline as key-value pairs, where the key corresponds to a field on `Clusterable::Holding`.

It is invoked as:
`bundle exec ruby bin/holdings_deleter.rb --key_1 val_1 ... --key_n val_n`

Internally the criteria are joined with an `AND`-operator, so:

`bundle exec ruby bin/holdings_deleter.rb --organization starfleet --status WD`

... would delete all holdings held by starfleet AND with status WD, nothing else.

Additional non-field control switches are: 

* `--noop` if you don't actually want to execute the deletes
* `--verbose` for extra logging
* `--leave_empties` if you don't want to delete empty clusters that may result from deleting holdings.
* `--help` for the full set of options available.
