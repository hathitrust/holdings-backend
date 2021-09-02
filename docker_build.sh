#!/bin/bash

DOCKERFILE=Dockerfile.prod
ORGANIZATION=hathitrust
PROJECT=holdings-client
TAG=$1
if [[ -z $TAG ]]; then
  TAG="concordance_validation"
fi

docker build . -f ./$DOCKERFILE -t $ORGANIZATION/$PROJECT:$TAG &&
  docker push $ORGANIZATION/$PROJECT:$TAG
