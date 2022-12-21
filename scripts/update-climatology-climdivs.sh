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

archvdir="$DATA_OUT/observations/land_air/all_ranges/us/degree_days/%Y/%m/%d"
climodir="$DATA_OUT/observations/land_air/all_ranges/us/degree_days/climatology/$period"
printf "\nData will be placed in: $climodir\n\n"
read -s -p "Press [Enter] to continue or [Ctrl-C] to exit"
printf "\n\nCreating raw 363 climate divisions climatologies\n"
read -t 3 -p ""

printf "\nCooling Degree Days\n"

perl make-raw-climatology-climdivs.pl -a $archvdir/cdd_climdivs_%Y%m%d.txt -o $climodir/cdd_climdivs_%m%d.txt -p $period

printf "\nCorn Growing Degree Days\n"

perl make-raw-climatology-climdivs.pl -a $archvdir/gdd-corn_climdivs_%Y%m%d.txt -o $climodir/gdd-corn_climdivs_%m%d.txt -p $period

printf "\nHeating Degree Days\n"

perl make-raw-climatology-climdivs.pl -a $archvdir/hdd_climdivs_%Y%m%d.txt -o $climodir/hdd_climdivs_%m%d.txt -p $period

# --- Create smoothed climatology ---

printf "\nCreating smoothed 363 climate divisions climatologies\n"
read -t 3 -p ""

printf "\nCooling Degree Days\n"

perl smooth-climatology-climdivs.pl -a $climodir/cdd_climdivs_%m%d.txt -o $climodir/cdd_climdivs_smoothed_%m%d.txt -w 5

printf "\nCorn Growing Degree Days\n"

perl smooth-climatology-climdivs.pl -a $climodir/gdd-corn_climdivs_%m%d.txt -o $climodir/gdd-corn_climdivs_smoothed_%m%d.txt -w 5

printf "\nHeating Degree Days\n"

perl smooth-climatology-climdivs.pl -a $climodir/hdd_climdivs_%m%d.txt -o $climodir/hdd_climdivs_smoothed_%m%d.txt -w 5

# --- Exit script ---

printf "\nAll done!\n"

exit 0

