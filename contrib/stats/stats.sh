#!/bin/sh
LNCLI=lncli
TZ="GMT"
DAY=0
INCHANNELS=0
OUTCHANNELS=0
BALANCE=0
ALIASES=0

help() {
    echo 'Usage: stats.sh [-d DAYS] [-i] [-o] [-b] [-a] [-h]
Gather statistics about the earned fees and money spent on rebalancing channels

Options:
-d DAYS     Get stats for the DAYS day before today (1 for yesterday etc.),
            negative value means last -DAYS (e.g. -7 means "last 7 days")
-i          Show channels sorted by inbound money traffic
-o          Show channels sorted by outbound money traffic
-b          Show channels balanced by traffic score (in+out)/abs(in-out)-1, most active and balanced first
-a          Show related node aliases in channel reports (significantly slows down output!)
'
}

while getopts d:iobah f
do
    case $f in
    d) DAY=$OPTARG
    ;;
    i) INCHANNELS=1
    ;;
    o) OUTCHANNELS=1
    ;;
    b) BALANCE=1
    ;;
    a) ALIASES=1
    ;;
    h) help
       exit 1
    ;;
    esac
done
shift $(( OPTIND-1 ))

which jq >/dev/null
if [ $? -ne 0 ]
then
  echo "Please install jq ('apt install jq' or similar command)."
  exit 1
fi

if [ -z "$1" ]
then
  echo "Specify the stats file name (e.g. stats.csv)"
  exit 1
fi

CSVFILE="$1"
if [ $DAY -ge 0 ]
then
    START=$(date -d 'today-'${DAY}'days 00:00:00 '$TZ +%s)
    END=$(date -d 'tomorrow-'${DAY}'days 00:00:00 '$TZ +%s)
else
    START=$(date -d 'today+'${DAY}'days 00:00:00 '$TZ +%s)
    END=$(date -d 'tomorrow 00:00:00 '$TZ +%s)
fi
{ 
    ${LNCLI} fwdinghistory --start_time ${START} --end_time ${END} --max_events -1 |
     jq -r '.forwarding_events[] | "\(.timestamp),\(.chan_id_out),\(.chan_id_in),-\(.amt_out_msat),-\(.fee_msat)"'
    cat "$CSVFILE"
} | awk -f stats.awk -v TSFROM=${START} -v TSTO=${END} -v IN=${INCHANNELS} -v OUT=${OUTCHANNELS} -v BALANCE=${BALANCE} -v ALIASES=${ALIASES}
