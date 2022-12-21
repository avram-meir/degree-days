#!/bin/bash

if [ -s ~/.profile ] ; then
	. ~/.profile
fi

usage() {
	printf "Usage :\n"
	printf "   $(basename "$0") period\n"
	printf "     period  : climatology period to use, e.g., 1991-2020\n"
}

# --- Get command line args ---

period=""
if [ "$#" == 1 ] ; then
    period=$1
else
    usage >&2
    exit 1
fi

# --- Create raw climatology ---

climodir="$DATA_OUT/observations/land_air/all_ranges/us/degree_days/climatology/$period"
printf "\nData will be placed in: $climodir\n\n"
read -s -p "Press [Enter] to continue or [Ctrl-C] to exit"
printf "\n\nCreating population and fuel weighted degree days climatologies\n"
read -t 3 -p ""

printf "\nCooling Degree Days\n"

day="2004-01-01"
while [ "$day" != 2005-01-01 ] ; do
    MM=$(date +%m --date "$day")
    DD=$(date +%d --date "$day")
    perl weighted-degree-days.pl -c ../config/weights.config -i $climodir/cdd_climdivs_${MM}${DD}.txt -o $climodir/cdd_weighted_${MM}${DD}.txt
    day=$(date +%Y-%m-%d --date "${day} + 1 day")
done

printf "\nHeating Degree Days\n"

day="2004-01-01"
while [ "$day" != 2005-01-01 ] ; do
    MM=$(date +%m --date "$day")
    DD=$(date +%d --date "$day")
    perl weighted-degree-days.pl -c ../config/weights.config -i $climodir/hdd_climdivs_${MM}${DD}.txt -o $climodir/hdd_weighted_${MM}${DD}.txt
    day=$(date +%Y-%m-%d --date "${day} + 1 day")
done

# --- Create smoothed climatology ---

printf "\nCreating smoothed population and fuel weighted degree days climatologies\n"
read -t 3 -p ""

printf "\nCooling Degree Days\n"

day="2004-01-01"
while [ "$day" != 2005-01-01 ] ; do
    MM=$(date +%m --date "${day}")
    DD=$(date +%d --date "${day}")
    perl weighted-degree-days.pl -c ../config/weights.config -i $climodir/cdd_climdivs_smoothed_${MM}${DD}.txt -o $climodir/cdd_weighted_smoothed_${MM}${DD}.txt
    day=$(date +%Y-%m-%d --date "${day} + 1 day")
done

printf "\nHeating Degree Days\n"

day="2004-01-01"
while [ "$day" != 2005-01-01 ] ; do
    MM=$(date +%m --date "$day")
    DD=$(date +%d --date "$day")
    perl weighted-degree-days.pl -c ../config/weights.config -i $climodir/hdd_climdivs_smoothed_${MM}${DD}.txt -o $climodir/hdd_weighted_smoothed_${MM}${DD}.txt
    day=$(date +%Y-%m-%d --date "${day} + 1 day")
done

# --- Exit script ---

printf "\nAll done!\n"

exit 0

