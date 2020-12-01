#!/usr/bin/env bash

set -euo pipefail

sourceDir=$1
repo=$2
attempt="1"
destDir=$sourceDir

csvFile="$destDir/summary.csv"

# Recreate the summary
if [[ -f "$csvFile" ]]; then
    rm "$csvFile"
fi
echo "Repository,Attempt,Runner,Build Time,CPU,CPU 95%,Disk Read IOPS,Disk Read IOPS 95%,Disk Read IOPS Peak,Disk Write IOPS,Disk Write IOPS 95%,Disk Write IOPS Peak,Disk Read MB/s,Disk Read MB/s 95%,Disk Read MB/s Peak,Disk Write MB/s,Disk Write MB/s 95%,Disk Write MB/s Peak,Available Memory,Available Memory 95%" > "$csvFile"

shopt -s nullglob
for cpu in $sourceDir/*-iostat_cpu.csv
do
    devices=${cpu/_cpu/_devices}
    runner=$(basename -- $cpu)
    runner=${runner%-*}
    timing="$sourceDir/$runner-timing.txt"
    memory="$sourceDir/$runner-vmstat.txt"

    # extract into CSV:

    vals=$(cat $cpu | datamash --header-in --sort --field-separator=, mean 2 perc:95 2)
    cpu_mean=${vals%,*}
    cpu_P95=${vals#*,}

    buildTime=$(cat $timing)

    # headers:
    #   1 datetime
    #   2 device
    #   3 r/s
    #   4 w/s
    #   5 rMB/s
    #   6 wMB/s
    #   7 rrqm/s
    #   8 wrqm/s
    #   9 %rrqm
    #   10 %wrqm
    #   11 r_await
    #   12 w_await
    #   13 aqu-sz
    #   14 rareq-sz
    #   15 wareq-sz
    #   16 svctm
    #   17 %util

    # headers (alt):
    #   1 datetime,
    #   2 device,
    #   3 r/s,
    #   4 rMB/s,
    #   5 rrqm/s,
    #   6 %rrqm,
    #   7 r_await,
    #   8 rareq-sz,
    #   9 w/s,
    #   10 wMB/s,
    #   11 wrqm/s,
    #   12 %wrqm,
    #   13 w_await,
    #   14 wareq-sz,
    #   15 d/s,
    #   16 dMB/s,
    #   17 drqm/s,
    #   18 %drqm,
    #   29 d_await,
    #   20 dareq-sz,
    #   21 aqu-sz,
    #   22 %util

    # Check for the alternate headers
    columns="3,5,4,6"
    if grep -q "dareq" $devices; then
        columns="3,4,9,10"
    fi

    # Find the most active device
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # Mac
        deviceData=$(cat $devices | datamash --header-in --sort --field-separator=, mean $columns perc:95 $columns max $columns --group=2 | sort -nr -k2 -t, | head -n 1)
    else
        # Linux
        deviceData=$(cat $devices | datamash --header-in --sort --field-separator=, mean $columns perc:95 $columns max $columns --group=2 | sort -nr -k2 -t, | head --lines=1)
    fi

    # Values is: device, rmean,rmbmean,wmean,wmbmean, rp95,rmbp95,wp95,wmbp95 rmax,rmbmax,wmax,wmbmax
    #                        2       3     4       5     6      7    8      9   10     11   12     13
    diskIO_r_mean=$(echo $deviceData | cut -d, -f 2)
    diskIO_r_P95=$(echo $deviceData | cut -d, -f 6)
    diskIO_r_max=$(echo $deviceData | cut -d, -f 10)
    diskIO_w_mean=$(echo $deviceData | cut -d, -f 4)
    diskIO_w_P95=$(echo $deviceData | cut -d, -f 8)
    diskIO_w_max=$(echo $deviceData | cut -d, -f 12)

    #vals=$(cat $devices | datamash --header-in --sort --field-separator=, mean 2 perc:95 2)
    diskMBs_r_mean=$(echo $deviceData | cut -d, -f 3)
    diskMBs_r_P95=$(echo $deviceData | cut -d, -f 7)
    diskMBs_r_max=$(echo $deviceData | cut -d, -f 11)
    diskMBs_w_mean=$(echo $deviceData | cut -d, -f 5)
    diskMBs_w_P95=$(echo $deviceData | cut -d, -f 9)
    diskMBs_w_max=$(echo $deviceData | cut -d, -f 13)

    # Memory
    #memData=$(cat $memory | datamash --header-in --sort --field-separator=, mean "free" perc:95 "free")
    #availMem_mean=$(echo $memData | cut -d, -f 1)
    #availMem_P95=$(echo $memData | cut -d, -f 2)
    availMem_mean=0
    availMem_P95=0

    line="$repo,$attempt,$runner,$buildTime,$cpu_mean,$cpu_P95,$diskIO_r_mean,$diskIO_r_P95,$diskIO_r_max,$diskIO_w_mean,$diskIO_w_P95,$diskIO_w_max,$diskMBs_r_mean,$diskMBs_r_P95,$diskMBs_r_max,$diskMBs_w_mean,$diskMBs_w_P95,$diskMBs_w_max,$availMem_mean,$availMem_P95"
    echo "$line" >> "$csvFile"
done