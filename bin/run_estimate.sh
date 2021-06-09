#!/bin/bash

if [[ -z $1 ]]; then
  echo "Usage: $0 /path/to/ocns" 
  exit 1;
fi

echo /usr/src/app/bin/run_generic_job.sh bundle exec ruby /usr/src/app/bin/compile_estimated_IC_costs.rb $1
