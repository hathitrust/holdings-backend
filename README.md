# Print Holdings persistent data store

[![Build Status](https://travis-ci.org/hathitrust/holdings-backend.svg?branch=master)](https://travis-ci.org/hathitrust/holdings-backend)


## Development/testing

### Prerequisites

* [Docker](https://docs.docker.com/install/)
* [Docker Compose](https://docs.docker.com/compose/install/)

```bash
docker-compose build
docker-compose up -d
docker-compose run --rm dev bundle install
docker-compose run --rm dev bundle exec rspec
```
