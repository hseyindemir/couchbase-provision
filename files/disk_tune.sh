#!/usr/bin/env bash

disk=()
while IFS= read -r -d $'\0' device; do
    device=${device/\/dev\//}
    disk+=($device)
done < <(find "/dev/" -regex '/dev/sd[a-z]\|/dev/vd[a-z]\|/dev/hd[a-z]' -print0)

for i in `seq 0 $((${#disk[@]}-1))`; do
    echo deadline > /sys/block/${disk[$i]}/queue/scheduler
    echo 1024 > /sys/block/${disk[$i]}/queue/nr_requests
    echo 100 > /sys/block/${disk[$i]}/queue/iosched/read_expire 
    echo 4 > /sys/block/${disk[$i]}/queue/iosched/writes_starved 
    echo 0 > /sys/block/${disk[$i]}/queue/rotational
    echo 0 > /sys/block/${disk[$i]}/queue/add_random
    echo 2 > /sys/block/${disk[$i]}/queue/rq_affinity
done
