#!/bin/bash

# --- Usage ---

usage() {
	printf "\nupdate-archives.sh : A template script to create and update your archives\n\n"
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

# --- Do stuff here ---

printf "\nDate received (YYYY/MM/DD): %s\n" `date +%Y/%m/%d --date "${update}"`
printf "This is a template script, you have to add content to it for it to update your archive\n\n"

exit 0

