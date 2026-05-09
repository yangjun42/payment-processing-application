#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"

json_value() {
  local key="$1"
  sed -n "s/.*\"$key\":\"\\([^\"]*\\)\".*/\\1/p"
}

post_payment() {
  local amount="$1"
  local reference="$2"
  local key="$3"
  curl -sS -w '\n%{http_code}' \
    -H 'Content-Type: application/json' \
    -X POST "$BASE_URL/payments" \
    -d "{\"amount\":$amount,\"currency\":\"EUR\",\"reference\":\"$reference\",\"idempotencyKey\":\"$key\"}"
}

assert_status() {
  local response="$1"
  local expected="$2"
  local status="${response##*$'\n'}"
  if [ "$status" != "$expected" ]; then
    echo "Expected HTTP $expected but got $status"
    echo "${response%$'\n'*}"
    exit 1
  fi
}

response_body() {
  printf '%s' "${1%$'\n'*}"
}

wait_for_state() {
  local payment_id="$1"
  local expected="$2"
  local attempts="${3:-45}"

  for _ in $(seq 1 "$attempts"); do
    local body
    body="$(curl -sS "$BASE_URL/payments/$payment_id")"
    local state
    state="$(printf '%s' "$body" | json_value state)"
    if [ "$state" = "$expected" ]; then
      printf '%s' "$body"
      return 0
    fi
    sleep 1
  done

  echo "Payment $payment_id did not reach $expected"
  curl -sS "$BASE_URL/payments/$payment_id"
  exit 1
}

run_approved_flow() {
  local key="e2e-approved-$(date +%s)"
  local created
  created="$(post_payment 12.50 E2E-APPROVED "$key")"
  assert_status "$created" 202

  local body
  body="$(response_body "$created")"
  local payment_id
  payment_id="$(printf '%s' "$body" | json_value paymentId)"
  local completed
  completed="$(wait_for_state "$payment_id" COMPLETED)"
  printf '%s\n' "$completed"

  local duplicate
  duplicate="$(post_payment 12.50 E2E-APPROVED "$key")"
  assert_status "$duplicate" 202
  local duplicate_id
  duplicate_id="$(response_body "$duplicate" | json_value paymentId)"
  if [ "$duplicate_id" != "$payment_id" ]; then
    echo "Duplicate idempotency key returned a different payment id"
    exit 1
  fi

  local conflict
  conflict="$(post_payment 13.00 E2E-APPROVED "$key")"
  assert_status "$conflict" 409
}

run_decline_flow() {
  local key="e2e-decline-$(date +%s)"
  local created
  created="$(post_payment 22.00 E2E-DECLINE "$key")"
  assert_status "$created" 202
  local payment_id
  payment_id="$(response_body "$created" | json_value paymentId)"
  local failed
  failed="$(wait_for_state "$payment_id" FAILED)"
  printf '%s\n' "$failed"
  local status
  status="$(printf '%s' "$failed" | json_value paymentServiceStatus)"
  if [ "$status" != "DECLINED" ]; then
    echo "Expected DECLINED business failure but got $status"
    exit 1
  fi
}

run_retry_flow() {
  local key="e2e-error-$(date +%s)"
  local created
  created="$(post_payment 33.00 E2E-ERROR "$key")"
  assert_status "$created" 202
  local payment_id
  payment_id="$(response_body "$created" | json_value paymentId)"
  local failed
  failed="$(wait_for_state "$payment_id" FAILED 60)"
  printf '%s\n' "$failed"
  local status
  status="$(printf '%s' "$failed" | json_value paymentServiceStatus)"
  local attempts
  attempts="$(printf '%s' "$failed" | sed -n 's/.*"attemptCount":\([0-9]*\).*/\1/p')"
  if [ "$status" != "TECHNICAL_FAILURE" ]; then
    echo "Expected TECHNICAL_FAILURE after retries but got $status"
    exit 1
  fi
  if [ "$attempts" != "3" ]; then
    echo "Expected 3 attempts after retry exhaustion but got $attempts"
    exit 1
  fi
}

run_approved_flow
run_decline_flow
run_retry_flow

echo "E2E verification passed"
