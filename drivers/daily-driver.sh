#!/bin/bash

if [ -s ~/.profile ] ; then
        . ~/.profile
fi

# --- Usage ---

usage() {
	printf "\nUsage : %s [options]\n\n" $(basename $0)
	printf "Options : \n"
	printf "   -b <string>       Backfill period (valid date delta, e.g., '-30 days')\n"
	printf "   -c <filename>     Configuration file listing archive files to check\n"
	printf "   -d <date>         Date to check and update in the archive\n"
	printf "       or\n"
	printf "   -d <date1 date2>  Date range to check and update in the archive\n"
	printf "                     If -b option is also provided, the backfilling period\n"
	printf "                     will be set prior to date1\n"
	printf "   -h                Print this usage message and exit\n"
	printf "   -l <filename>     List of dates to check\n\n"
}

# --- Process input args ---

while getopts ":b:c:d:hl:" option; do
	case $option in
		b)
			back=("$OPTARG");;
		c)
			config=("$OPTARG");;
		d)
			dates+=("$OPTARG");;
		h)
			usage
			exit 0;;
		l)
			listfile=("$OPTARG");;
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

# --- Set dates to check and update ---

dstart=""
dstop=""

if [ ${#dates[@]} -eq 0 ] ; then
	dstart=$(date +%Y%m%d --date "today")
	dstop=$dstart
elif [ ${#dates[@]} -eq 1 ] ; then
	dstart=${dates[0]}
	dstop=$dstart
elif [ ${#dates[@]} -ge 2 ] ; then
	dstart=${dates[0]}
	dstop=${dates[1]}
fi

# --- Validate the dates ---

startdate=$(date +%Y%m%d --date $dstart)

if [ $? -ne 0 ] ; then
	printf "%s is an invalid date\n" $dstart >&2
	usage >&2
	exit 1
fi

stopdate=$(date +%Y%m%d --date $dstop)

if [ $? -ne 0 ] ; then
	printf "%s is an invalid date\n" $dstop >&2
	usage >&2
	exit 1
fi

if [ $startdate -gt $stopdate ] ; then
	tempdate=$enddate
	enddate=$startdate
	startdate=$tempdate
fi

# --- Add backfilling if provided ---

if ! [ -z "$back" ] ; then

	startdate=$(date +%Y%m%d --date "$startdate $back")

	if [ $? -ne 0 ] ; then
		printf "%s is an invalid value for option -b\n" $back >&2
		usage >&2
		exit 1
	fi

fi

# --- Store range of dates into array ---

date=$startdate

until [ $date -gt $stopdate ] ; do
	datelist+=("$date")
	date=$(date +%Y%m%d --date "$date+1day")
done

# --- Get list of dates to update if provided ---

if ! [ -z $listfile ] ; then

	if [ -s $listfile ] ; then

		# --- Execute the file as a bash script to pull in datelist ---

		. $listfile

		if [ -z "$missingdates" ] ; then
			printf "No missingdates parameter found in %s\n" $listfile >&2
		fi

	else
		printf "%s is empty or not created - skipping\n" $listfile
	fi

fi

# --- Add missingdates to datelist ---

for md in "${missingdates[@]}" ; do

	if [[ ! " ${datelist[*]} " =~ " ${md} " ]]; then
		datelist+=("$md")
	fi

done

# --- Sort dates into ascending order ---

IFS=$'\n' datelist=($(sort <<<"${datelist[*]}"))
unset IFS

# --- Get archive information from config file ---

alwaysupdate=0

if [ -z $config ] ; then    # Always update if no config file was supplied
	alwaysupdate=1
elif [ -s $config ] ; then  # Config file supplied

	# --- Execute the file as a bash script to pull in expected variables ---

	. $config

	if [ -z "$files" ] ; then
		printf "No files parameter found in %s\n" $config >&2
		alwaysupdate=1
	fi

else
	printf "%s is an empty file or does not exist\n" $config >&2
	usage >&2
	exit 1
fi

# --- Loop through all days in the range defined by startdate and enddate ---

printf "Scanning and updating archive for the specified dates\n"

cd $(dirname "$0")

failed=0
date=$startdate

for date in "${datelist[@]}" ; do
	update=0

	if [ $alwaysupdate -eq 1 ] ; then
		update=1
	else

	# --- Scan archive for missing files ---

		for fil in "${files[@]}" ; do
			filename=$(date +"${fil}" --date "${date}")

			if ! [ -s $filename ] ; then
				update=1
			fi
			
		done

	fi

	if [ $update -eq 1 ] ; then
		printf "Updating archive for %s\n" $date

#		***************************************
#		*                                     *
#		*   Your amazing stuff happens here   *
#		*                                     *
#		***************************************

		./update-archives.sh -d $date

		# --- Check return code for nonzero status (problems) ---

		if [ $? -ne 0 ] ; then
			((failed++))
			printf "Something went wrong on %d\n" $date

			# --- Assume any files created by problem run are corrupt and remove them ---

			for fil in "${files[@]}" ; do
				filename=$(date +"${fil}" --date "${date}")

				if [ -s $filename ] ; then
					rm -rf $filename
				fi

			done

			baddays+=("$date")

		else

			# --- Check archive to ensure expected files got created ---

			notfound=0

			for fil in "${files[@]}" ; do
				filename=$(date +"${fil}" --date "${date}")

				if ! [ -s $filename ] ; then
					printf "Error: %s not created\n" $filename >&2
					notfound=1
				fi

			done

			if [ $notfound -ne 0 ] ; then
				((failed++))
				baddays+=("$date")
			fi

		fi

	else
		printf "Archive already complete for %s\n" $date
	fi

done

if [ $failed -ne 0 ] ; then

	if ! [ -z $listfile ] ; then
		printf "missingdates=(%s)\n" "${baddays[*]}" > $listfile
	fi

	printf "There were errors detected on %d days\n" $failed >&2
	exit 1
else

	if ! [ -z $listfile ] ; then

		if [ -e $listfile ] ; then
			rm $listfile
		fi

	fi

	printf "No errors detected\n"
fi

exit 0

