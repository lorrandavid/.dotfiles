Release Title
- Release v2.4.0

----------------------------------------

Summary
This release improves payment reliability by introducing asynchronous retry
processing and includes internal performance improvements.

----------------------------------------

What’s New
- Payments are now retried asynchronously to reduce failed orders caused by
  temporary provider issues.

----------------------------------------

Improvements & Refactors
- Refactored order processing logic for better reliability.
- Improved database query performance for retry operations.

----------------------------------------

Breaking Changes
- No breaking changes

----------------------------------------

Operational Notes
- A new background worker is required for payment retries.
- Ensure the retry worker is deployed before enabling the feature.
- Monitor queue depth during the first deployment.

----------------------------------------

Known Risks & Watchouts
- Retry logic must be monitored to avoid duplicate payment attempts.
- Rollback of the database index requires manual intervention if needed.

----------------------------------------

Commits Included
- a1b2c3d Refactor payment retry logic
- d4e5f6g Add index to orders table
- h7i8j9k Introduce retry worker
