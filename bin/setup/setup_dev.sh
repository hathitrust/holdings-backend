#!/bin/bash

$(dirname ${BASH_SOURCE[0]})/setup_test.sh

docker compose up --wait mongo_dev
docker compose exec -T mongo_dev bash /tmp/bin/setup/rs_initiate.sh mongo_dev
docker compose run --rm dev bundle exec ruby lib/tasks/build_database.rb

