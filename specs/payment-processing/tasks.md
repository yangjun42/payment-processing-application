# Task Ledger

| Status | Task | Evidence |
| --- | --- | --- |
| DONE | Capture payment-processing requirements in a Spec Kit workflow | `specs/payment-processing/spec.md`, `plan.md`, `data-model.md`, `contracts/openapi.yaml` |
| DONE | Initialize Spring Boot 3 / Java 21 service | `pom.xml`, `PaymentProcessingApplication` |
| DONE | Add PostgreSQL schema and Flyway migration | `src/main/resources/db/migration/V1__initial_schema.sql` |
| DONE | Implement asynchronous payment intake API | `PaymentController`, `PaymentIntakeService`, `PaymentResponse` |
| DONE | Implement idempotency and request-hash conflict handling | `RequestHasher`, `PaymentIntakeServiceTest` |
| DONE | Persist payment state and attempt history | `Payment`, `PaymentAttempt`, repository tests |
| DONE | Implement transactional outbox | `OutboxEvent`, `OutboxPublisher`, intake service transaction |
| DONE | Implement durable RabbitMQ publishing and manual-ack worker | `RabbitConfig`, `OutboxPublisher`, `PaymentWorker`, `PaymentProcessor` |
| DONE | Implement retry classification, backoff, and stale recovery | `RetryPolicy`, `PaymentRetryScheduler`, related tests |
| DONE | Implement configurable Payment REST API simulator | `SimulatorPaymentController`, `PaymentSimulatorProperties`, `application-simulator.yml` |
| DONE | Provide Docker Compose runtime with PostgreSQL, RabbitMQ, simulator, gateway, and scalable app replicas | `docker-compose.yml`, `deploy/nginx.conf`, `Dockerfile` |
| DONE | Add smoke, E2E, and k6 verification scripts | `scripts/smoke-test.sh`, `scripts/e2e-verify.sh`, `k6/payment-flow.js` |
| DONE | Add unit and integration coverage for reliability behavior | `src/test/java/**`, Testcontainers PostgreSQL and RabbitMQ integration test |
| DONE | Document architecture, trade-offs, restart behavior, simulator behavior, and run commands | `README.md` |
| DONE | Document test and performance evidence | `TEST_REPORT.md` |
