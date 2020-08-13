#!/bin/bash

docker-compose build
docker-compose run --rm dev bundle install
docker-compose up -d mongo_test mariadb
docker-compose run --rm -e MONGOID_ENV=test dev bin/wait-for mongo_test:27017 -- echo "mongo is ready"
docker-compose exec mongo_test bash /tmp/bin/rs_initiate.sh mongo_test
docker-compose run --rm -e MONGOID_ENV=test dev bundle exec ruby lib/tasks/build_database.rb
