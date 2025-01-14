#!/bin/bash

bindir=$(dirname $(realpath $0))

for file in $bindir/../sql/*.sql; do 
  if [[ "$(basename $file)" = "001_users.sql" ]];
  then echo "skipping $file";
    continue;
  fi
  echo "loading $file"
  $bindir/mariadb.sh -vv < $file
done
