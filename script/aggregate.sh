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
echo "Repository,Attempt,Runner,Build Time,CPU,CPU 95%,Disk Read IOPS,Disk Read IOPS 95%,Disk Write IOPS,Disk Write IOPS 95%,Disk Read MB/s,Disk Read MB/s 95%,Disk Write MB/s,Disk Write MB/s 95%,Available Memory,Available Memory 95%" > "$csvFile"

shopt -s nullglob
for cpu in $sourceDir/*-iostat_cpu.csv
do
    devices=${cpu/_cpu/_devices}
    runner=$(basename -- $cpu)
    runner=${runner%-*}
    timing="$sourceDir/$runner-timing.txt"
    memory="$sourceDir/$runner-vmstat.txt"

    # extract into CSV:
    # Repository,Attempt,Build Time,CPU,CPU 95%,Disk IOPS,Disk IOPS 95%,Disk MB/s,Disk MB/s 95%,Available Memory,Available Memory 95%

    vals=$(cat $cpu | datamash --header-in --sort --field-separator=, mean 2 perc:95 2)
    cpu_mean=${vals%,*}
    cpu_P95=${vals#*,}

    buildTime=$(cat $timing)

    # headers:
    #   1 datetime
    #   2 device
    #   3 Device
    #   4 r/s
    #   5 w/s
    #   6 rMB/s
    #   7 wMB/s
    #   8 rrqm/s
    #   9 wrqm/s
    #   10 %rrqm
    #   11 %wrqm
    #   12 r_await
    #   13 w_await
    #   14 aqu-sz
    #   15 rareq-sz
    #   16 wareq-sz
    #   17 svctm
    #   18 %util

    # headers (alt):
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

    # Check for the alternate headers
    columns="4,6,5,7"
    if grep -q "dareq" $devices; then
        columns="4,5,10,11"
    fi

    # Find the most active device
    # Linux
    deviceData=$(cat $devices | datamash --header-in --sort --field-separator=, mean $columns perc:95 $columns --group=2 | sort -nr -k2 -t, | head --lines=1)
    # Mac
    # deviceData=$(cat $devices | datamash --header-in --sort --field-separator=, mean $columns perc:95 $columns --group=2 | sort -nr -k2 -t, | head -n 1)

    # Values is: device, rmean,rmbmean,wmean,wmbmean, rp95,rmbp95,wp95,wmbp95
    #                        2       3     4       5     6      7    8      9
    diskIO_r_mean=$(echo $deviceData | cut -d, -f 2)
    diskIO_r_P95=$(echo $deviceData | cut -d, -f 6)
    diskIO_w_mean=$(echo $deviceData | cut -d, -f 4)
    diskIO_w_P95=$(echo $deviceData | cut -d, -f 8)

    #vals=$(cat $devices | datamash --header-in --sort --field-separator=, mean 2 perc:95 2)
    diskMBs_r_mean=$(echo $deviceData | cut -d, -f 3)
    diskMBs_r_P95=$(echo $deviceData | cut -d, -f 7)
    diskMBs_w_mean=$(echo $deviceData | cut -d, -f 5)
    diskMBs_w_P95=$(echo $deviceData | cut -d, -f 9)

    # Memory
    memData=$(cat $memory | datamash --header-in --sort --field-separator=, mean "free" perc:95 "free")
    availMem_mean=$(echo $memData | cut -d, -f 1)
    availMem_P95=$(echo $memData | cut -d, -f 2)

    line="$repo,$attempt,$runner,$buildTime,$cpu_mean,$cpu_P95,$diskIO_r_mean,$diskIO_r_P95,$diskIO_w_mean,$diskIO_w_P95,$diskMBs_r_mean,$diskMBs_r_P95,$diskMBs_w_mean,$diskMBs_w_P95,$availMem_mean,$availMem_P95"
    echo "$line" >> "$csvFile"
done