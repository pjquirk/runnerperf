#!/usr/bin/env bash

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

repo="pytorch"
attempt="1"

sourceDir="$scriptDir/../analysis/summarized/$repo/$attempt"
destDir="$scriptDir/../analysis/summarized/$repo/$attempt"
#mkdir -p $destDir
csvFile="$destDir/summary.csv"

# Recreate the summary
if [[ -f "$csvFile" ]]; then
    rm "$csvFile"
fi
echo "Repository,Attempt,Runner,Build Time,CPU,CPU 95%,Disk IOPS,Disk IOPS 95%,Disk MB/s,Disk MB/s 95%,Available Memory,Available Memory 95%" > "$csvFile"


shopt -s nullglob
for cpu in $sourceDir/*-iostat_cpu.csv
do
    devices=${cpu/_cpu/_devices}
    runner=$(basename -- $cpu)
    runner=${runner%-*}
    timing="$sourceDir/$runner-timing.txt"

    # extract into CSV:
    # Repository,Attempt,Build Time,CPU,CPU 95%,Disk IOPS,Disk IOPS 95%,Disk MB/s,Disk MB/s 95%,Available Memory,Available Memory 95%

    vals=$(cat $cpu | datamash --header-in --sort --field-separator=, mean 2 perc:90 2)
    cpu_mean=${vals%,*}
    cpu_P95=${vals#*,}

    buildTime=$(cat $timing)

    # find the most active device
    # headers:
    #   1 datetime,
    #   2 device,
    #   3 Device,
    #   4 r/s,
    #   5 rMB/s,
    #   6 rrqm/s,
    #   7 %rrqm,
    #   8 r_await,
    #   9 rareq-sz,
    #   10 w/s,
    #   11 wMB/s,
    #   12 wrqm/s,
    #   13 %wrqm,
    #   14 w_await,
    #   15 wareq-sz,
    #   16 d/s,
    #   17 dMB/s,
    #   18 drqm/s,
    #   19 %drqm,
    #   20 d_await,
    #   21 dareq-sz,
    #   22 aqu-sz,
    #   23 %util

    datamash --header-in --sort --field-separator=, sum 4 sum 10

    #vals=$(cat $devices | datamash --header-in --sort --field-separator=, mean 2 perc:90 2)
    diskIO_mean=${vals%,*}
    diskIO_P95=${vals#*,}

    #vals=$(cat $devices | datamash --header-in --sort --field-separator=, mean 2 perc:90 2)
    diskMBs_mean=""
    diskMBs_P95=""

    availMem_mean=""
    availMem_P95=""

    line="$repo,$attempt,$runner,$buildTime,$cpu_mean,$cpu_P95,$diskIO_mean,$diskIO_P95,$diskMBs_mean,$diskMBs_P95,$availMem_mean,$availMem_P95"
    echo "$line" >> "$csvFile"
done