# Remediation policy

Use SonarQube data to guide fixes, not to blindly rewrite code.

## Good v1 auto-fix targets

- low-risk code smells with precise file and line context
- straightforward bug fixes backed by existing tests
- narrow duplication cleanup in a single module or file cluster
- dead code or unused-variable cleanup when the repo checks confirm safety

## Duplication consolidation policy

Duplication remediation is interactive by design. The agent must not choose a consolidation
approach without user input unless an existing shared solution is clearly identified.

### When an existing shared solution is found

If the codebase already has a utility, service, base class, or shared module that handles
the duplicated logic, the agent may propose refactoring both files to use it. This is
considered low-risk and can proceed like a normal conservative fix.

### When no shared solution exists

The agent **must ask the user** which consolidation approach to use. Present these options:

1. **Extract shared utility/service** — create a new module in a shared location
2. **Base class or mixin** — introduce inheritance to consolidate shared behavior
3. **Composition/delegation** — wrap the shared logic in a composable unit
4. **Accept the duplication** — if the coupling cost outweighs the deduplication benefit

Factors to surface when presenting options:
- How many files share the duplication
- Whether the duplication is across module/package boundaries
- Whether the duplicated code touches sensitive areas
- The estimated coupling that each approach would introduce

### Buffer accounting

The removal target includes a configurable buffer (default 20%) because refactoring
often introduces small new duplication blocks. For example, extracting a shared utility
means both callers now import and call the same function — the function body itself may
register as a new small duplication if it resembles other code in the project.

## Require extra caution

- public API changes
- concurrency-sensitive code
- data migrations
- error handling paths with unclear caller expectations
- duplication across package or module boundaries (higher coupling risk)
- duplication in generated code or scaffolding (may be intentional)

## Do not auto-fix by default

- authentication or authorization flows
- crypto or secret handling
- security hotspots that need human judgment
- architecture-scale duplication refactors across many packages
- issues without clear local verification
- duplication where no consolidation approach has been approved by the user
