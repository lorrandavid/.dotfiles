# Remediation policy

Use SonarQube data to guide fixes, not to blindly rewrite code.

## Good v1 auto-fix targets

- low-risk code smells with precise file and line context
- straightforward bug fixes backed by existing tests
- narrow duplication cleanup in a single module or file cluster
- dead code or unused-variable cleanup when the repo checks confirm safety

## Require extra caution

- public API changes
- concurrency-sensitive code
- data migrations
- error handling paths with unclear caller expectations

## Do not auto-fix by default

- authentication or authorization flows
- crypto or secret handling
- security hotspots that need human judgment
- architecture-scale duplication refactors across many packages
- issues without clear local verification
