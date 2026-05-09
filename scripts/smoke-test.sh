#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
IDEMPOTENCY_KEY="smoke-$(date +%s)"

response="$(
  curl -sS -w '\n%{http_code}' \
    -H 'Content-Type: application/json' \
    -X POST "$BASE_URL/payments" \
    -d "{\"amount\":12.50,\"currency\":\"EUR\",\"reference\":\"SMOKE-APPROVED\",\"idempotencyKey\":\"$IDEMPOTENCY_KEY\"}"
)"

status="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$status" != "202" ]; then
  echo "Expected 202 from POST /payments but got $status"
  echo "$body"
  exit 1
fi

payment_id="$(printf '%s' "$body" | sed -n 's/.*"paymentId":"\([^"]*\)".*/\1/p')"
if [ -z "$payment_id" ]; then
  echo "Unable to parse paymentId from response:"
  echo "$body"
  exit 1
fi

for _ in $(seq 1 30); do
  status_body="$(curl -sS "$BASE_URL/payments/$payment_id")"
  state="$(printf '%s' "$status_body" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')"
  case "$state" in
    COMPLETED|FAILED)
      echo "$status_body"
      exit 0
      ;;
    RETRY_PENDING|RECEIVED|ENQUEUED|IN_PROGRESS)
      sleep 1
      ;;
    *)
      echo "Unexpected state '$state'"
      echo "$status_body"
      exit 1
      ;;
  esac
done

echo "Payment did not reach a terminal state within 30 seconds: $payment_id"
exit 1
