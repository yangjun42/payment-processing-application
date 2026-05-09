# Implementation Plan

## Phase 1: Project Setup

- Initialize a standalone Spring Boot 3.x and Java 21 project.
- Add PostgreSQL, RabbitMQ, Flyway, JPA, validation, Actuator, JUnit 5, Awaitility, and Testcontainers dependencies.
- Create project-local documentation and status tracking.

## Phase 2: API and Persistence

- Implement `POST /payments` and status APIs.
- Persist payments and attempts.
- Enforce idempotency conflict detection through request hashing.
- Create a transactional outbox row in the same transaction as the payment.

## Phase 3: Messaging and Worker

- Publish outbox events to a durable RabbitMQ queue.
- Consume with manual acknowledgement.
- Persist attempt outcomes and final states.
- Handle duplicate delivery as a no-op for terminal payments.

## Phase 4: Retry and Recovery

- Classify technical failures as retryable.
- Use exponential backoff bounded by configuration.
- Requeue due retries via outbox.
- Recover stale `IN_PROGRESS` rows after restart.

## Phase 5: Scalability and Verification

- Provide Docker Compose services for PostgreSQL, RabbitMQ, simulator, payment app, and gateway.
- Support `docker compose up --build --scale payment-app=3`.
- Provide smoke and k6 scripts.
- Record verification evidence in `TEST_REPORT.md`.

## Phase 6: Documentation

- Keep README commands aligned with real files.
- Keep architecture notes, run commands, and verification evidence easy to inspect from the repository root.
