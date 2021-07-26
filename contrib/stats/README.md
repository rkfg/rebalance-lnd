# Rebalance analysis

This script gathers some useful stats for you to see how balanced your expenses and earnings are.

# Prerequisites

The script requires `mawk` (the default awk version in Debian-based distros), `jq` and `lncli`. Specify the path to `lncli` at the top of `stats.sh` or leave it by default if `lncli` is in your `$PATH`. You can also setup your timezone in `TZ` parameter, it affects the day boundaries. Ride-The-Lightning uses `GMT+0` by default so it's the same here.

# Usage

Use `-s` parameter with a file name (here we assume it's `stats.csv`) when launching `rebalance.py`. It will write the successful rebalance data there to be analyzed later with this script.

```
Usage: stats.sh [-d DAYS] [-t] [-i] [-o] [-b] [-a] [-h] stats.csv
Gather statistics about the earned fees and money spent on rebalancing channels

Options:
-d DAYS     Get stats for the DAYS day before today (1 for yesterday etc.),
            negative value means last -DAYS (e.g. -7 means "last 7 days")
-t          Show total fees spent and earned
-i          Show channels sorted by inbound money traffic
-o          Show channels sorted by outbound money traffic
-b          Show channels balanced by traffic score (in+out)/abs(in-out)-1, most active and balanced first
-a          Show related node aliases in channel reports (significantly slows down output!)
```

# Flags meaning

`-t` shows your total profit/loss for the chosen time period. It's the sum of all fees earned for payment forwards and fees spent on rebalances as well as their difference and average rates (in ppm).
`-i` shows the most used inbound channels with total amount and fees earned from that. You can find the channels that should have more inbound capacity to accept bigger payments and earn more fees here.
`-o` shows the most used outbound channels with total amount and fees earned from that. You can find the channels that should have more outbound capacity to send bigger payments and earn more fees here.
`-b` shows the most balanced and used channels first and less used and balanced later. A balanced channels forwards payments in both directions so you shouldn't rebalance it as often. The score formula is simple but effective, it equals 0 if the channel is one-sided and it grows infinitely if the in/out amounts are close and total amount is high. A one-sided channel with high activity is still valuable (but a balanced highly active channel is the best of course!), not very active one-sided channels should probably be closed after a month or two.
`-a` queries node aliases for every channel printed in `-i`, `-o` and `-b`. It takes time but helps to quickly find the channel you need in the UI if you use one (like `lntop` or `RTL`).