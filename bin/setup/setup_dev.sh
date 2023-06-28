#!/bin/bash

$(dirname ${BASH_SOURCE[0]})/setup_test.sh

docker compose run --rm processor echo "mongo is ready"
docker compose exec -T mongo_dev bash /tmp/bin/setup/rs_initiate.sh mongo_dev
docker compose run --rm processor bundle exec ruby lib/tasks/build_database.rb

