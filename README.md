# Print Holdings persistent data store



![Build Status](https://github.com/hathitrust/holdings-backend/workflows/Docker%20Build/badge.svg)


## Prerequisites / Setup

* [Docker](https://docs.docker.com/install/)
* [Docker Compose](https://docs.docker.com/compose/install/)

Run the following script to build and start the Docker containers:

```bash
bash bin/setup_dev.sh
```

## Running the tests

`docker-compose run --rm dev bundle exec rspec`

## Clearing out/resetting the data
For resetting everything (cleaning up containers & their persistent volumes):

```shell script
# Clear it out
docker-compose down # to stop services
docker volume rm holdings-backend_data_db # to clear out the development database
docker volume rm holdings-backend_gem_cache # to clear out gems

# Rebuild it
bash bin/setup_dev.sh
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
* `docker-compose run --rm dev bundle exec bin/add_ocn_resolutions.rb <filepath>`
* `docker-compose run --rm dev bundle exec bin/add_ht_items.rb <filepath>`
* `docker-compose run --rm dev bundle exec bin/add_print_holdings.rb
 <filepath>` (full file)
* `docker-compose run --rm dev bundle exec bin/add_print_holdings.rb -u
 <filepath>` (update file)

### Loading the OCLC Concordance file

The _oclc concordance file_ is a single file with two columns, each line
representing a pair of OCLC numbers that should be treated as equivalent.

There are ≈ 60M rows in this file. Depending on your hardware, a full
load will run into tens-of-hours (40-60 hours on a basic iMac desktop).

The OCLC concordance source file is not for redistribution.

To load the OCLC concordance file:
  * Get the file from our [private Box account](https://umich.app.box.com/file/643800968350)
    and put it somewhere under the repository root 
  * Make sure your docker cluster is up and running 
    * `docker-compose ps` (run from the repo root) should show mongo running 
    * `bin/setup_dev.sh` if it's not up
  * From the root of the repository:
    * `docker-compose run --rm dev bundle exec bin/add_ocn_resolutions.rb <filepath>`, where
      * `docker-compose run` is the command
      * `--rm` says to fire up a container for this and then tear it back 
      down so it isn't still running
      * `<filepath>` is the path _relative to the repository root_
       of the (full-or-partial) OCLC resoutions file. This file may be gzipped or not. 


### Loading the HathiFiles

The _hathifiles_ come in both monthly "full-file" and daily "changes"
versions. Each line represents a single Hathitrust item/volume,
although some columns contain "record-level" data that is just repeated
for each item line. See the 
[Hathifiles file format specification](https://www.hathitrust.org/hathifiles_description)
for more info if you're interested.

To load a Hathifile (either a full file or an update):
  * Grab the file from [the Hathifiles webpage](https://www.hathitrust.org/hathifiles)
  or directly from `/htapps/www/sites/www.hathitrust.org/files/hathifiles`
  * `docker-compose run --rm dev bundle exec bin/add_ht_items.rb <filepath>`
  where the components are exactly as for the OCLC concordance file.

### Loading (scrubbed) print holdings

Print holdings are provided by each partner as a set of three files 
(for single-volume monographs, multi-volume monographs, and serials)
that describe their own holdings, keyed on OCLC number, with one line for
each copy they own (so, there might be identical lines representing multiple
copies of the same item). 

These raw files are "scrubbed" and verified, resulting in scrubbed files.

To load a scrubbed file:
  * Get the file(s) you want from `/htapps/mwarin.babel/phdb_scripts/data/loadfiles/`
  * Add UUIDs for tracking whether the individual line has been processed: `bin ruby/add_uuid.rb infile > outfile`
  * `docker-compose run --rm dev bundle exec bin/add_print_holdings.rb outfile`

