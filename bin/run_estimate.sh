#!/bin/bash

TIME=$(date +"%Y%m%d%H%M%S")
if [[ -z $1 ]]; then
  echo "Usage: $0 /path/to/ocns"
  exit 1;
fi

/usr/src/app/bin/run_generic_job.sh estimate-$TIME bundle exec ruby /usr/src/app/bin/compile_estimated_IC_costs.rb $1
