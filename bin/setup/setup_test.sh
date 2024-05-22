#!/bin/bash

docker compose build "$@"
docker compose run --rm dev bundle install
docker compose up --wait mongo_test
docker compose exec -T mongo_test bash /tmp/bin/setup/rs_initiate.sh mongo_test
docker compose run --rm test bundle exec ruby lib/tasks/build_database.rb
