#!/bin/sh
LNCLI=lncli
if [ -z "$1" ]
then
  echo "Specify the stats file name (e.g. stats.csv)"
  exit 1
fi
TZ="GMT"
CSVFILE="$1"
DAY=${2:-0}
if [ $DAY -ge 0 ]
then
    START=$(date -d 'today-'${DAY}'days 00:00:00 '$TZ +%s)
    END=$(date -d 'tomorrow-'${DAY}'days 00:00:00 '$TZ +%s)
else
    START=$(date -d 'today+'${DAY}'days 00:00:00 '$TZ +%s)
    END=$(date -d 'tomorrow 00:00:00 '$TZ +%s)
fi
{ 
    ${LNCLI} fwdinghistory --start_time ${START} --end_time ${END} --max_events -1 | awk -f callbacks.awk -f JSON.awk -
    cat "$CSVFILE"
} | awk -f stats.awk -v TSFROM=${START} -v TSTO=${END}
