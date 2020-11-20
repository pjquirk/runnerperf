#!/usr/bin/env bash

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
    IFS=$'\n' read -d '' -r -a lines < "$timing"

    t0=$(date -j -f "%a, %d %b %Y %k:%M:%S %z" "${lines[0]}" +%s)
    t1=$(date -j -f "%a, %d %b %Y %k:%M:%S %z" "${lines[1]}" +%s)
    seconds=$((t1-t0))
    echo $seconds > "$outputFile"
done