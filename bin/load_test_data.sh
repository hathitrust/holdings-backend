#!/bin/bash

# This script can be used as an example to load data in testdata

# Full test data is not supplied with the code

# Run this outside docker; it will start all required services.
# Running this script assumes you have already run --rm bin/setup_dev.sh

docker-compose up --scale processor=3 -d sidekiq_web processor redis 
docker-compose run --rm dev bin/setup/wait-for redis:6379 -- echo "redis is ready"

echo "generating fake data"
docker-compose run --rm dev bundle exec ruby bin/generate_fake_data.rb

# also a good test of concurrency & split/merge operations -- concordance rules
# being loaded at the same time htitems are being loaded

mkdir -p testdata/concordance/diffs
cp testdata/ocns_fake.tsv testdata/concordance/diffs/comm_diff_2022-01-01.txt.adds
touch testdata/concordance/diffs/comm_diff_2022-01-01.txt.deletes
echo "queueing job for concordance load"
docker-compose run --rm phctl load concordance 2022-01-01

echo "queueing job for htitems load"
docker-compose run --rm phctl load ht_items testdata/htitems_fake.tsv

# todo split & load multiple chonks
chunk_count=10
outdir=testdata/fake_holdings
mkdir -p $outdir
split -d --verbose --number=l/$chunk_count testdata/umich_fake_holdings.ndj "$outdir/split_"
for chunk in $outdir/split_*[0-9]; do
  mv $chunk $chunk.ndj
done

for chunk in $outdir/split_*.ndj; do
  echo "queueing job for holdings load $chunk"
  docker-compose run --rm phctl load holdings $chunk
done
