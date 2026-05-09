# Submission Note

Hello,

This repository contains my implementation of the payment-processing application.

## Design Choice

I implemented the API asynchronously:

- `POST /payments` persists the payment request and returns `202 Accepted` with a `paymentId` and status URL.
- Background workers process the external Payment REST API call through PostgreSQL, RabbitMQ, and a transactional outbox.
- Clients can poll `GET /payments/{paymentId}` for final status and attempt history.

I chose this design because it gives better restart safety, retry visibility, and horizontal scalability than a synchronous request/response implementation. The trade-off is that clients do not receive the final payment result in the initial `POST` response.

## Reliability Model

- Payment row and outbox event are written in the same database transaction.
- RabbitMQ messages are durable.
- Workers use manual acknowledgement and acknowledge only after durable DB state is committed.
- Processing is at-least-once, not exactly-once.
- Duplicate or redelivered messages are safe because terminal payments are no-ops.
- External REST side effects are handled with an idempotent/reconcilable key based on the local `paymentId`.
- Technical failures such as timeout, HTTP 5xx, and HTTP 429 are retried with backoff.
- Business declines are terminal `FAILED`.
- Stale `IN_PROGRESS` payments are recovered after the configured threshold.

## Verification

Local verification completed:

```text
DOCKER_HOST=unix://$HOME/.colima/default/docker.sock TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock mvn -Dmaven.repo.local=.m2/repository test
Tests run: 16, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

The Maven suite includes a Testcontainers integration test with real PostgreSQL and RabbitMQ containers for the API -> outbox -> RabbitMQ worker -> DB path.

```text
mvn -Dmaven.repo.local=.m2/repository -DskipTests package
BUILD SUCCESS
```

Docker Compose verification covered one app replica for smoke and three app replicas for E2E:

```bash
docker compose up --build --scale payment-app=1 -d
./scripts/smoke-test.sh
docker compose up --build --scale payment-app=3 -d
./scripts/e2e-verify.sh
```

E2E scenarios covered:

- approved payment reaches `COMPLETED`;
- duplicate same idempotency key returns the same payment id;
- same idempotency key with changed amount returns `409`;
- business decline becomes terminal `FAILED`;
- technical failure retries to max attempts and then becomes terminal `FAILED` with `TECHNICAL_FAILURE`;
- RabbitMQ queue is drained and outbox events are all published after processing.

k6 single-instance load smoke:

```text
145 iterations, 290 HTTP requests
checks_succeeded: 580/580
http_req_failed: 0.00%
http_req_duration p95: 33.92ms
```

k6 horizontally scaled load smoke with three app replicas:

```text
150 iterations, 300 HTTP requests
checks_succeeded: 600/600
http_req_failed: 0.00%
http_req_duration p95: 29.90ms
```

## Documentation

The README documents:

- async vs sync trade-offs;
- idempotency handling;
- retry handling;
- simulator behavior;
- Docker Compose scaling setup;
- known limitations.

Additional evidence and design artifacts:

- `TEST_REPORT.md`
- `README.md`
- `specs/payment-processing/spec.md`
- `specs/payment-processing/plan.md`
- `specs/payment-processing/data-model.md`
- `specs/payment-processing/contracts/openapi.yaml`
