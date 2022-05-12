#!/bin/bash

$(dirname ${BASH_SOURCE[0]})/setup_test.sh

docker-compose up -d mongo_dev pushgateway
docker-compose run --rm dev bin/setup/wait-for mongo_dev:27017 -- echo "mongo is ready"
docker-compose exec -T mongo_dev bash /tmp/bin/setup/rs_initiate.sh mongo_dev
docker-compose run --rm -e MONGOID_ENV=development dev bundle exec ruby lib/tasks/build_database.rb

