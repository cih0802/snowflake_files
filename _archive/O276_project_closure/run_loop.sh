#!/bin/sh
cd /workspace || exit 1
while true; do
    echo "=== Batch start at $(date) ===" >> /tmp/run_loop.log
    timeout 180 python3 _archive/O276_project_closure/o276_resume.py --apply --max-sec 120 </dev/null >> /tmp/run_loop.log 2>&1
    rc=$?
    echo "=== Batch finished rc=$rc at $(date) ===" >> /tmp/run_loop.log
    stat=$(python3 _archive/O276_project_closure/o276_resume.py </dev/null 2>&1)
    echo "STAT: $stat" >> /tmp/run_loop.log
    to_move=$(echo "$stat" | grep -o 'to_move [0-9]*' | awk '{print $2}')
    if [ "$to_move" = "0" ] || [ -z "$to_move" ]; then
        echo "ALL DONE!" >> /tmp/run_loop.log
        break
    fi
    sleep 2
done
