#!/bin/bash

# Call:
# docker-compose run --rm -e MONGOID_ENV=test dev bash bin/process_new_holdings.sh

# Checks new_files_dir for new files, scrubs and loads them
# and moves them to seen_files_dir.

# Set up dirs
# Get abs path to this dir.
pushd `dirname $0` > /dev/null;
script_path=`pwd`;
popd > /dev/null;

clear

new_files_dir=`realpath $script_path/../data/new/`
mkdir --verbose -p $new_files_dir

seen_files_dir=`realpath $script_path/../data/seen/`
mkdir --verbose -p $seen_files_dir

scrub_path=`realpath $script_path/../lib/autoscrub.rb`
scrub_command="bundle exec ruby $scrub_path"

load_path=`realpath $script_path/../bin/add_print_holdings.rb`
load_command="bundle exec ruby $load_path"

# Check new_files_dir for files
new_files="ls -w1 $new_files_dir/*.tsv"
echo -e "new files:\n$new_files"

eval "$new_files" | while read new_file ; do
    echo "$scrub_command $new_file"
    eval "$scrub_command $new_file"
    scrub_exit_code=$?
    echo "scrub exit code $scrub_exit_code"
    if [ "$scrub_exit_code" = "0" ]; then
	echo "Scrub OK"
	mv --verbose $new_file $seen_files_dir
    else
	echo "Failed scrubbing $new_file"
    fi
    echo "----------"
done
