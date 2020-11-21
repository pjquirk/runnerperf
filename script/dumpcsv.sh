#!/usr/bin/env bash

set -euo pipefail

sourceDir=$1
destDir=$2

mkdir -p $destDir
rm -rf $destDir/*

shopt -s nullglob
for f in $sourceDir/*-iostat.txt
do
    # Dump CPU/device stats to csv
    filename=$(basename -- "$f")
    filenameWithoutExt=${filename%.*}
    filenameWithoutExt=${filenameWithoutExt/\./_}  # get rid of periods in label names
    echo $filenameWithoutExt

    outputFile="$destDir/$filenameWithoutExt.csv"
    iostat-cli --data "$f" --output "$outputFile" csv

    # Get build timing
    timing=${f/-iostat/-timing}
    outputFile="$destDir/${filenameWithoutExt/iostat/timing}.txt"
    # Mac
    #IFS=$'\n' read -d '' -r -a lines < "$timing"
    # Linux
    mapfile -t lines < "$timing"

    t0=$(date -d "${lines[0]}" +%s)
    t1=$(date -d "${lines[1]}" +%s)
    seconds=$((t1-t0))
    echo $seconds > "$outputFile"

    # Dump memory to csv
    memory=${f/-iostat/-vmstat}
    outputFile="$destDir/${filenameWithoutExt/iostat/vmstat}.txt"
    # Skip the header, merge whitespace and convert to commas (for csv)
    tail --lines=+2 "$memory" | tr -s ' ' ',' > "$outputFile"
done