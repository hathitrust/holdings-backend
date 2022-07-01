#!/bin/bash

MONGO_SERVICE="${MONGO_SERVICE:-$1}"

mongosh <<EOT
  rs.initiate(
    {
      _id: "rs0",
      version: 1,
      members: [
        { _id: 0, host: "$MONGO_SERVICE:27017" }
      ]
    }
  )
EOT
