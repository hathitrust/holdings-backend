#!/bin/bash

# Call:
# docker-compose run --rm -e MONGOID_ENV=test dev bash bin/process_new_holdings.sh

# Checks files_to_scrub_dir for new files, scrubs and loads them
# and moves them to seen_files_dir.

# Set up dirs
# Get abs path to this dir.
pushd `dirname $0` > /dev/null;
script_path=`pwd`;
popd > /dev/null;

clear

delim="----------"

files_to_scrub_dir=`realpath $script_path/../data/new/`
mkdir --verbose -p $files_to_scrub_dir

seen_files_dir=`realpath $script_path/../data/seen/`
mkdir --verbose -p $seen_files_dir

scrub_path=`realpath $script_path/../lib/autoscrub.rb`
scrub_command="bundle exec ruby $scrub_path"

load_path=`realpath $script_path/../bin/add_print_holdings.rb`
load_command="bundle exec ruby $load_path"

member_data_dir=`realpath $script_path/../data/member_data/`

# Check files_to_scrub_dir for files to scrub.
files_to_scrub="ls -w1 $files_to_scrub_dir/*.tsv"
echo -e "new files:\n$files_to_scrub"
eval "$files_to_scrub" | while read new_file ; do
    echo "$scrub_command $new_file"
    eval "$scrub_command $new_file"
    scrub_exit_code=$?
    echo "scrub exit code $scrub_exit_code"
    if [ "$scrub_exit_code" = "0" ]; then
	echo "Scrub OK"
	mv --verbose $new_file $seen_files_dir
    else
	echo "Failed scrubbing $new_file"
	# Failed files left in place for now
    fi
    echo $delim
done

# Load scrubbed files.
files_to_load="ls -w1 $member_data_dir/*/ready_to_load/*.ndj"
echo -e "Files to load:\n$files_to_load"
eval "$files_to_load" | while read load_file ; do
     echo "$load_command $load_file"
     eval "$load_command $load_file"
     load_exit_code=$?
    if [ "$load_exit_code" = "0" ]; then
	echo "Load OK"
	loaded_file_dir=`echo $load_file | sed -r 's/ready_to_load/loaded/'`
	mv --verbose $load_file $loaded_file_dir
    else
	echo "Failed loading $load_file"
	# Failed files left in place for now
    fi
     echo $delim
done
