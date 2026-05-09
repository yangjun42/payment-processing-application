# Data Model

## `payments`

Stores the durable state of each accepted payment.

| Column | Purpose |
| --- | --- |
| `id` | Stable payment id returned to callers and used for worker idempotency |
| `idempotency_key` | Optional client idempotency key, unique when present |
| `request_hash` | Canonical hash of amount, currency, and reference |
| `amount`, `currency`, `reference` | Original business request |
| `state` | Current state in the payment state machine |
| `attempt_count` | Number of external call attempts started |
| `max_attempts` | Retry cap copied from configuration at intake time |
| `next_retry_at` | Due time for retryable technical failures |
| `last_error` | Latest error visible in status API |
| `payment_service_response_id` | External approved payment id, when available |
| `payment_service_status` | External status or terminal failure classification |
| `payment_service_response` | Raw external response for trace/debug visibility |
| `created_at`, `updated_at`, `completed_at` | Lifecycle timestamps |
| `version` | Optimistic lock column |

## `payment_attempts`

Stores one row per external Payment REST API attempt.

| Column | Purpose |
| --- | --- |
| `id` | Attempt id |
| `payment_id` | Parent payment |
| `attempt_number` | Attempt ordinal |
| `started_at`, `finished_at`, `duration_ms` | Timing evidence |
| `result` | `SUCCESS`, `TECHNICAL_FAILURE`, or `BUSINESS_FAILURE` |
| `http_status` | External HTTP status when available |
| `error_message` | Classification detail |
| `raw_response` | External response body when available |

## `outbox_events`

Stores durable work to publish to RabbitMQ.

| Column | Purpose |
| --- | --- |
| `id` | Outbox event id |
| `aggregate_id` | Payment id |
| `event_type` | `PaymentReceived` or `PaymentRetryDue` |
| `payload` | Serialized worker message |
| `status` | `NEW`, `PUBLISHED`, or `FAILED` |
| `attempt_count` | Publish attempts |
| `next_publish_at` | Due time for publisher |
| `created_at`, `published_at` | Outbox lifecycle timestamps |
| `last_error` | Latest publish error |

## Invariants

- No two rows may share the same non-null idempotency key.
- Terminal payments are not changed by duplicate deliveries.
- A worker message is not acknowledged before durable state is saved.
- Due retry work is represented by a durable outbox event.
- Stale `IN_PROGRESS` rows are returned to `RETRY_PENDING`.
