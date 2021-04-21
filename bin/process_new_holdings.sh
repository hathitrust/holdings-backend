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

# Filter out undesirable files.
filter_junk () {
    egrep -v '~|#|\.out\.ndj'
}

new_files_dir=`realpath $script_path/../data/new/`
mkdir --verbose -p $new_files_dir

seen_files_dir=`realpath $script_path/../data/seen/`
mkdir --verbose -p $seen_files_dir

scrub_path=`realpath $script_path/../lib/autoscrub.rb`

# Check new_files_dir for files
new_files=`ls $new_files_dir | filter_junk`
echo -e "new files:\n$new_files"

# Get the distinct member_ids from filenames in new_files_dir
member_ids=`ls $new_files_dir | grep -Po '^[a-z\-]+' | sort -u`
echo -e "member_ids:\n$member_ids"
echo "--------------"

# For each member_id, get the matching files and run autoscrub.
for member in ${member_ids// / }
do
    echo "Looking for files for: $member"
    member_files=`ls $new_files_dir | grep "^${member}_" | filter_junk | awk -v nfd=$new_files_dir '{print nfd "/" $1}' | tr '\n' ' '`

    if [ -z "$member_files" ]
    then
	echo "Found no files for $member."
    else
	echo "found: $member_files"
	# Run scrub on new files.
	scrub_command="bundle exec ruby $scrub_path $member_files"
	echo "###"
	echo "Running: $scrub_command"
	eval $scrub_command

	# Check scrub output.
	output_dir=`bundle exec ruby $script_path/../lib/scrub_output_structure.rb $member | grep -Po '"latest_output":"[^"]+"' | tr -d '"' | awk -F':' '{print $2}'`
	echo "output_dir: $output_dir"

	# Load scrub output into mongo
	bundle exec ruby $script_path/../bin/add_print_holdings.rb $output_dir/*.ndj	
    fi
done
