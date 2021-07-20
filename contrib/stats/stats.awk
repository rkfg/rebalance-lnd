#!/usr/bin/awk -f

function unquote(s) {
	gsub("\"", "", s)
	return s
}

function abs(v) {return v < 0 ? -v : v}

BEGIN {
  fees_earned = 0
  fees_spent = 0
  amount_forwarded = 0
  amount_rebalanced = 0
  delete inchan_amount
  delete inchan_fees
  delete outchan_amount
  delete outchan_fees
  FS=","
  if (ALIASES) {
    cmd = "lncli getinfo | jq -r .identity_pubkey"
    cmd | getline nodeid
  }
}

$1 >= TSFROM && $1 <= TSTO { 
  if ($4 > 0) {
    fees_spent += $5
    amount_rebalanced += $4
  } else {
    fees_earned -= $5
    amount_forwarded -= $4
    inchan_fees[$3] -= $5
    inchan_amount[$3] -= $4
    outchan_fees[$2] -= $5
    outchan_amount[$2] -= $4
  }
}

function get_channel_node(c) {
  node = ""
  cmd = "lncli getchaninfo " c " 2>/dev/null | jq -r .node2_pub,.node1_pub"
  while ((cmd | getline node) > 0) {
    if (node != nodeid) {
      break
    }
  }
  close(cmd)
  if (node == "") {
    return "<not found>"
  }
  cmd = "lncli getnodeinfo " node " | jq -r .node.alias"
  cmd | getline alias
  close(cmd)
  return alias
}

function format_channel(c) {
  if (ALIASES) {
    return sprintf("%18s | %-23s", c, substr(get_channel_node(c), 1, 24))
  } else {
    return c
  }
}

END {
  if (TOTALFEES) {
    fwppm = 0
    rbppm = 0
    tppm = 0
    if (amount_forwarded > 0) {
      fwppm = fees_earned * 1e6 / amount_forwarded
    }
    if (amount_rebalanced > 0) {
      rbppm = fees_spent * 1e6 / amount_rebalanced
    }
    if (amount_forwarded + amount_rebalanced > 0) {
      tppm = (fees_earned - fees_spent) * 1e6 / (amount_forwarded + amount_rebalanced)
    }
    printf("Fees balance:\n%25s | %-11s | %-6s\n", "Amount", "Fees", "ppm")
    printf("Forwarded:  %13.3f | %-11.3f | %-6.0f\n", amount_forwarded / 1000, fees_earned / 1000, fwppm)
    printf("Rebalanced: %13.3f | %-11.3f | %-6.0f\n", amount_rebalanced / 1000, fees_spent / 1000, rbppm)
    printf("Total:      %13.3f | %-11.3f | %-6.0f\n",
          (amount_forwarded + amount_rebalanced) / 1000,
          (fees_earned - fees_spent) / 1000,
          tppm)
  }
  CHANFMT="%18s"
  CHANHEADER="Channel ID"
  SORTCHANCMD="sort -t '|' -grk 3"
  SORTBALCMD="sort -t '|' -grk 4 -k 2 -k 3"
  if (ALIASES) {
    CHANFMT="%44s"
    CHANHEADER=sprintf("%18s | %-23s", "Channel ID", "Node ID")
    SORTCHANCMD="sort -t '|' -grk 4"
    SORTBALCMD="sort -t '|' -grk 5 -k 3 -k 4"
  }
  if (IN) {
    printf("\nInbound forwarding stats:\n" CHANFMT " | %13s | %-11s\n", CHANHEADER, "Amount", "Fees")
    for (c in inchan_amount) {
      printf(CHANFMT " | %13.3f | %-11.3f\n", format_channel(c), inchan_amount[c] / 1000, inchan_fees[c] / 1000) | SORTCHANCMD
    }
  }
  if (OUT) {
    printf("\nOutbound forwarding stats:\n" CHANFMT " | %13s | %-11s\n", CHANHEADER, "Amount", "Fees")
    for (c in outchan_amount) {
      printf(CHANFMT " | %13.3f | %-11.3f\n", format_channel(c), outchan_amount[c] / 1000, outchan_fees[c] / 1000) | SORTCHANCMD
    }
  }
  if (BALANCE) {
    delete bchans
    for (c in inchan_amount) {
      diff = abs(inchan_amount[c] - outchan_amount[c])
      if (diff == 0) {
        diff = 1
      }
      bchans[c] = (inchan_amount[c] + outchan_amount[c]) / diff - 1
    }
    for (c in outchan_amount) {
      diff = abs(inchan_amount[c] - outchan_amount[c])
      if (diff == 0) {
        diff = 1
      }
      bchans[c] = (inchan_amount[c] + outchan_amount[c]) / diff - 1
    }
    printf("\nBalance stats:\n" CHANFMT " | %13s | %-13s | %-13s\n", CHANHEADER, "Amount in", "Amount out", "Score")
    for (c in bchans) {
      printf(CHANFMT " | %13.3f | %-13.3f | %-13.3f\n", format_channel(c), inchan_amount[c] / 1000,
            outchan_amount[c] / 1000, bchans[c]) | SORTBALCMD
    }
  }
}