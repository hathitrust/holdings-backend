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

## System Operation

See [Routine Tasks for Holdings
System](https://hathitrust.atlassian.net/wiki/spaces/HAT/pages/2032107525/Routine+Tasks+for+Holdings+System)
(restricted access) for procedures for loading holdings, processing the OCLC
concordance, and running various reports.

## Debugging settings

Setting the `DEBUG` environment variable will log more information in reporting about individual data elements as they are processed.

Setting `LOG_SQL` will log each statement run against the database.

## IDE debugging (VS Code)

Requires the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension.

Open the `holdings-backend/` directory in VS Code. Use the Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`) and run `Dev Containers: Reopen in Container`. The dev container installs gems automatically and starts ruby-lsp.

To debug a spec, open the file, set a breakpoint, and run `Debug current spec` from the Run and Debug panel. You can also add `debugger` anywhere in application code to pause there when a spec calls into it.
