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

## Fix loop

1. Fetch issues for one project and scope.
2. Select one issue or one small duplication cluster.
3. Read the surrounding code and existing tests.
4. Apply the minimal fix.
5. Run repo validation from the current shell, keeping command examples shell-correct for Bash or PowerShell.
6. Wait for fresh Sonar analysis.
7. Confirm the specific issue count or metric improves.

## Evidence before claiming success

- target repo checks pass
- Sonar shows a newer completed analysis
- the issue disappeared, or the relevant measure improved
- no nearby higher-risk regression was introduced
