# This script is divided into 3 parts:
# SETUP, sets vars and asks for info
# DOWNLOAD, gets a bunch of data, using data from SETUP
# LOAD DATA, loads the data gotten from DOWNLOAD
# Call thusly:
# $ bash startup_load.sh

######## SETUP

hathifile="hathi_full.txt.gz"
holdings_server="punch.umdl.umich.edu"
holdings_data_dir="/htapps/mwarin.babel/phdb_scripts/data/loadfiles"

echo "Gonna ask you for username and password to $holdings_server (for scp use)."
echo "Make sure you are on VPN and have your 2FA handy."
echo -n "Username:"
read scp_username

######## DOWNLOAD

# Get all holdings files for members starting with "i"
# currently iastate, illinois, iu which is a neat subset @ ~750MB
scp $scp_username@$holdings_server:$holdings_data_dir/HT003_i* testdata/

# Download a hathifile.
curl https://www.hathitrust.org/filebrowser/download/296893 -o testdata/$hathifile

# Download a concordance file.
# todo > testdata/conc.tsv.gz

######## LOAD DATA

# Load a concordance file.
sudo docker-compose run --rm -e MONGOID_ENV=test dev bundle exec bin/add_ocn_resolutions.rb testdata/conc.tsv.gz

# Load a hathifile.
sudo docker-compose run --rm -e MONGOID_ENV=test dev bundle exec bin/add_ht_items.rb testdata/$hathifile

# Load holdings files
sudo docker-compose run --rm -e MONGOID_ENV=test dev bundle exec bin/add_print_holdings.rb testdata/HT003_i*
