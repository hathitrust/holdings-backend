#!/bin/bash

bindir=$(dirname $(realpath $0))
mariadb="mariadb -u $MARIADB_HOLDINGS_RW_USERNAME --password=$MARIADB_HOLDINGS_RW_PASSWORD -h $MARIADB_HOLDINGS_RW_HOST"
database=$MARIADB_HOLDINGS_RW_DATABASE

if [[ "$1" != "--force" ]]; then
  echo "This will reset the database $database and delete all existing data"
  echo -n "Are you sure? [y/N]: "

  read confirmation
  if [[ "$confirmation" != "y" ]]; then
    echo "Not resetting database"
    exit 2
  fi
fi


echo "recreating database $database"
  $mariadb <<EOT
DROP DATABASE IF EXISTS $database;
CREATE DATABASE $database;
EOT

for file in $bindir/../sql/*.sql; do 
  echo "loading $file"
  $mariadb $database < $file
done
