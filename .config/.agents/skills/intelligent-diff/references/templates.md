TL;DR
- Introduced asynchronous payment retry processing and refactored order logic.
- Backend and Infrastructure teams should review.
- Overall release risk: Medium

----------------------------------------

Walkthrough of Changes

Business Logic
- Refactored order retry flow to support asynchronous retries via a queue.
- This changes execution timing and error handling semantics.

Data / Migrations
- Added a new index on orders(status, created_at) to improve retry lookup
  performance.
- No automatic rollback included in the migration.

Infrastructure / Configuration
- Introduced a new background worker for payment retries.
- Updated queue visibility timeout configuration.

----------------------------------------

Architectural Impact

The release introduces asynchronous processing for payment retries.

[API]
  |
[Order Service]
  |
[Queue] ---> [Retry Worker]
                 |
             [Payment Provider]

----------------------------------------

Risk & Bug Analysis

⚠️ Commit a1b2c3d
- File(s): services/order_retry.ts
- Risk: Retry logic does not enforce idempotency keys.
- Why this matters in production:
  Network retries or worker restarts may cause duplicate charges.

⚠️ Commit d4e5f6g
- File(s): migrations/20240112_add_orders_index.sql
- Risk: Migration has no rollback strategy.
- Why this matters in production:
  Rollback may require manual intervention during incident response.

----------------------------------------

Review Checklist

- Verify idempotency protections in payment retry flow
- Confirm retry worker concurrency limits
- Test migration rollback in staging
- Load test async retry path
