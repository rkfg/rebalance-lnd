#!/usr/bin/awk -f

BEGIN {
  fees_earned = 0
  fees_spent = 0
  amount_forwarded = 0
  amount_rebalanced = 0
  FS=","
  printf("%25s | %-11s | %-6s\n", "Amount", "Fees", "ppm")
}

$1 >= TSFROM && $1 <= TSTO { 
  if ($4 > 0) {
    fees_spent += $5
    amount_rebalanced += $4
  } else {
    fees_earned -= $5
    amount_forwarded -= $4
  }
}

END {
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
  printf("Forwarded:  %13.3f | %-11.3f | %-6.0f\n", amount_forwarded / 1000, fees_earned / 1000, fwppm)
  printf("Rebalanced: %13.3f | %-11.3f | %-6.0f\n", amount_rebalanced / 1000, fees_spent / 1000, rbppm)
  printf("Total:      %13.3f | %-11.3f | %-6.0f\n",
        (amount_forwarded + amount_rebalanced) / 1000,
        (fees_earned - fees_spent) / 1000,
        tppm)
}