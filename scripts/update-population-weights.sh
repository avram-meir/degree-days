#!/bin/bash

if [ -s ~/.profile ] ; then
        . ~/.profile
fi

# --- Usage ---

usage() {
    printf "\nUsage : %s [options]\n\n" $(basename $0)
    printf "Options : \n"
    printf "   -h                Print this usage message and exit\n"
    printf "   -o                Output directory where weights get written\n"
    printf "   -y YYYY           Find populations files in ../populations/YYYY\n\n"
    printf "If no output directory is specified, weights will be written into ../weights/YYYY\n"
}

# --- Process input args ---

while getopts ":ho:y:" option; do
    case $option in
        h)
            usage
            exit 0;;
        o)
            output=("$OPTARG");;
        y)
            year=("$OPTARG");;
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

if [ -z $year ]; then
    printf "Error: Option -y is required\n" >&2
    usage >&2
    exit 1
fi

if [ -z $output ]; then
    output='../weights'
fi

mkdir -p $output
printf "Output directory is : %s\n" $output
printf "Year is : %s\n" $year

# --- Get lists of expected i/o files ---

climdivspops="../populations/${year}/climate_divisions_${year}.csv"
statespops=(
    "../populations/${year}/population_${year}.csv"
    "../populations/${year}/all-households_${year}.csv"
    "../populations/${year}/bottled-tank-lp-gas_${year}.csv"
    "../populations/${year}/coal-coke_${year}.csv"
    "../populations/${year}/electricity_${year}.csv"
    "../populations/${year}/fuel-oil-kerosene-etc_${year}.csv"
    "../populations/${year}/no-fuel_${year}.csv"
    "../populations/${year}/other-fuel_${year}.csv"
    "../populations/${year}/solar-energy_${year}.csv"
    "../populations/${year}/utility-gas_${year}.csv"
    "../populations/${year}/wood_${year}.csv"
)

climdivswts="${output}/climate_divisons.csv"
censuswts=(
    "${output}/population_census.csv"
    "${output}/all-households_census.csv"
    "${output}/bottled-tank-lp-gas_census.csv"
    "${output}/coal-coke_census.csv"
    "${output}/electricity_census.csv"
    "${output}/fuel-oil-kerosene-etc_census.csv"
    "${output}/no-fuel_census.csv"
    "${output}/other-fuel_census.csv"
    "${output}/solar-energy_census.csv"
    "${output}/utility-gas_census.csv"
    "${output}/wood_census.csv"
)
conuswts=(
    "${output}/population_conus.csv"
    "${output}/all-households_conus.csv"
    "${output}/bottled-tank-lp-gas_conus.csv"
    "${output}/coal-coke_conus.csv"
    "${output}/electricity_conus.csv"
    "${output}/fuel-oil-kerosene-etc_conus.csv"
    "${output}/no-fuel_conus.csv"
    "${output}/other-fuel_conus.csv"
    "${output}/solar-energy_conus.csv"
    "${output}/utility-gas_conus.csv"
    "${output}/wood_conus.csv"
)
uswts=(
    "${output}/population_us.csv"
    "${output}/all-households_us.csv"
    "${output}/bottled-tank-lp-gas_us.csv"
    "${output}/coal-coke_us.csv"
    "${output}/electricity_us.csv"
    "${output}/fuel-oil-kerosene-etc_us.csv"
    "${output}/no-fuel_us.csv"
    "${output}/other-fuel_us.csv"
    "${output}/solar-energy_us.csv"
    "${output}/utility-gas_us.csv"
    "${output}/wood_us.csv"
)

# --- Update weights based on populations files ---

cd "$(dirname "$0")"

perl update-population-weights.pl -p ${climdivspops} -r states -o $climdivswts

for (( j=0; j<${#statespops[@]}; j++ )); do
    perl update-population-weights.pl -p ${statespops[$j]} -r census -o ${censuswts[$j]}
    perl update-population-weights.pl -p ${statespops[$j]} -r conus -o ${conuswts[$j]}
    perl update-population-weights.pl -p ${statespops[$j]} -r us -o ${uswts[$j]}
done

exit 0

