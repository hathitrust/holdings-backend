# Print Holdings persistent data store

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
