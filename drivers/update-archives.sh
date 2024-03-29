#!/bin/bash

# --- Usage ---

usage() {
    printf "\nupdate-archives.sh : Update the daily degree days archives\n\n"
    printf "Usage : %s [options]\n\n" $(basename $0)
    printf "   -d <date>     Date to update in a format understandable by GNU date\n\n"
}

# --- Process input args ---

while getopts ":d:" option; do
    case $option in
        d)
            datearg=("$OPTARG");;
        :)
            printf "Error: Option -%s requires a value\n" $OPTARG >&2
            usage >&2
            exit 1;;
        *)
            printf "Error: Invalid usage\n" >&2
            usage >&2
            exit 1;;
    esac
done

# --- Validate the date ---

update=$(date +%Y%m%d --date $datearg)

if [ $? -ne 0 ] ; then
    printf "%s is an invalid date\n" $datearg >&2
    usage >&2
    exit 1
fi

YYYYMMDD=$(date +%Y%m%d --date $update)
YYYY=$(date +%Y --date $update)
MM=$(date +%m --date $update)
DD=$(date +%d --date $update)

# --- Update the various archives ---

error=0

printf "\n1. Calculating degree days on climate divisions and stations\n"

perl ../scripts/calculate-degree-days.pl -c ../config/degree_days.config -d ${update}

if [ $? -ne 0 ] ; then
    error=1
fi

printf "\n2. Create weighted degree days summaries for states, Census Divisions, US\n";

perl ../scripts/weighted-degree-days.pl -c ../config/weights.config -i $DATA_OUT/observations/land_air/all_ranges/us/degree_days/${YYYY}/${MM}/${DD}/cdd_climdivs_${YYYYMMDD}.txt -o $DATA_OUT/observations/land_air/all_ranges/us/degree_days/${YYYY}/${MM}/${DD}/cdd_weighted_${YYYYMMDD}.txt

if [ $? -ne 0 ] ; then
    error=1
fi 

perl ../scripts/weighted-degree-days.pl -c ../config/weights.config -i $DATA_OUT/observations/land_air/all_ranges/us/degree_days/${YYYY}/${MM}/${DD}/hdd_climdivs_${YYYYMMDD}.txt -o $DATA_OUT/observations/land_air/all_ranges/us/degree_days/${YYYY}/${MM}/${DD}/hdd_weighted_${YYYYMMDD}.txt

if [ $? -ne 0 ] ; then
    error=1
fi 

exit ${error}
