# Test Report

Date: 2026-05-09

## Environment

- Project: Payment Processing Application
- Java source target: 21
- Build tool: Maven
- Framework: Spring Boot 3.3.5
- Runtime stack: Docker Compose with PostgreSQL 16, RabbitMQ 3.13, Nginx gateway, payment app replicas, and simulator

## Automated Tests

Command:

```bash
DOCKER_HOST=unix://$HOME/.colima/default/docker.sock \
TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock \
mvn -Dmaven.repo.local=.m2/repository test
```

Result:

```text
Tests run: 16, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

The Maven suite includes focused unit tests and a Testcontainers integration test with real PostgreSQL and RabbitMQ containers for the API -> outbox -> RabbitMQ worker -> DB finalization path.

Coverage by test intent:

- state transition rules and terminal immutability;
- retry policy backoff and max-attempt behavior;
- stable request hashing;
- idempotency duplicate and conflict behavior;
- intake creates payment plus outbox event;
- approved external result completes payment;
- business decline becomes terminal failed;
- technical failure moves to retry pending;
- due retry creates a new outbox event and marks the payment enqueued;
- duplicate delivery of terminal payment is a no-op;
- Testcontainers verifies API intake, outbox publish, RabbitMQ worker consumption, durable DB finalization, and HTTP idempotency conflict behavior.

## Package Build

Command:

```bash
mvn -Dmaven.repo.local=.m2/repository -DskipTests package
```

Result:

```text
BUILD SUCCESS
target/payment-processing-application-0.1.0-SNAPSHOT.jar
```

## Single-Instance Runtime And Performance

Commands:

```bash
docker compose up --build --scale payment-app=1 -d
./scripts/smoke-test.sh
k6 run k6/payment-flow.js
```

Result:

```text
Smoke test reached COMPLETED with attemptCount=1.
k6: 145 iterations, 290 HTTP requests
k6 checks: 580/580 succeeded
http_req_failed: 0.00%
http_req_duration p95: 33.92ms
thresholds passed: http_req_failed rate<0.05, http_req_duration p(95)<1000
```

## Horizontally Scaled Runtime And Performance

Commands:

```bash
docker compose up --build --scale payment-app=3 -d
./scripts/e2e-verify.sh
k6 run k6/payment-flow.js
```

Compose confirmed three running `payment-app` replicas behind the gateway.

E2E scenarios verified:

- approved payment reaches `COMPLETED`;
- duplicate same idempotency key returns the same payment id;
- same idempotency key with changed amount returns `409`;
- `DECLINE` reference becomes terminal `FAILED` with `paymentServiceStatus=DECLINED`;
- `ERROR` reference retries technical failure to `attemptCount=3` and terminal `paymentServiceStatus=TECHNICAL_FAILURE`.

k6 result:

```text
150 iterations, 300 HTTP requests
checks_succeeded: 600/600
http_req_failed: 0.00%
http_req_duration p95: 29.90ms
thresholds passed: http_req_failed rate<0.05, http_req_duration p(95)<1000
```

Post-run invariants:

```text
payments by state: COMPLETED=156, FAILED=6
outbox by status: PUBLISHED=168
RabbitMQ payments.processing: messages=0, ready=0, unacknowledged=0
```

## Observations And Bottlenecks

- The three-replica run preserved correctness invariants: no queue backlog, all outbox events published, and all test payments reached terminal states.
- The scaled run improved p95 latency from 33.92ms to 29.90ms under this small k6 workload. The gain is modest because the test uses only five virtual users and the simulator delay plus gateway/DB overhead dominate.
- RabbitMQ and PostgreSQL are shared resources by design. Higher load would eventually bottleneck on database connection pool size, row-lock contention around retry/outbox updates, or simulator latency.
- The Nginx gateway keeps one public host port while routing to multiple app containers, which makes the Compose proof reproducible without changing client URLs.

## Suggested Optimizations

- Increase k6 scenarios and duration for capacity planning beyond this smoke-level proof.
- Tune app, PostgreSQL, and RabbitMQ connection pool sizes together when increasing replica counts.
- Add provider-side reconciliation endpoints or webhook handling if the real Payment Service supports them.
- Add metrics dashboards for queue depth, outbox publish lag, retry count, and payment terminal-state latency.
- Consider Kubernetes manifests later for production deployment automation; Docker Compose is the primary reproducible scaling proof for this project.
