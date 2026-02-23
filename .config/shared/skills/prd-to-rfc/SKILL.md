---
name: prd-to-rfc
description: Convert an existing PRD (from the write-a-prd skill) into a formal Request for Comments (RFC) document suitable for technical review and approval.
---

# PRD to RFC Skill

Convert a Product Requirements Document into a formal RFC that proposes a concrete technical design for review by engineers and stakeholders.

A PRD defines **WHAT** to build and **WHY**. An RFC defines **HOW** to build it and invites critique of the approach.

## Workflow

1. User requests: "Convert this PRD to an RFC" (and provides the PRD file or path)
2. **Read the PRD** in full
3. **Explore the codebase** to validate technical assumptions and discover constraints
4. **Ask clarifying questions** about ambiguous technical decisions (max one round of 3-5 questions)
5. **Draft the RFC** following the template below
6. **Review with user** — walk through key design decisions and trade-offs
7. Save RFC to `rfc-<feature-name>.md` in project root

## Input

A PRD produced by the `write-a-prd` skill containing at minimum:
- Problem Statement
- Solution overview
- User Stories
- Implementation Decisions
- Testing Decisions
- Out of Scope

## Clarifying Questions

Before drafting, explore the codebase and ask targeted questions about:

| Domain | Example Questions |
|--------|-------------------|
| Architecture | "Should this be a new module or extend an existing one?" |
| Data flow | "Where does this data originate? What transformations happen?" |
| Dependencies | "Are there version constraints on X? Can we introduce dependency Y?" |
| Failure modes | "What happens when service X is unavailable?" |
| Migration | "Is there existing data that needs migration? Can we do it lazily?" |
| Performance | "What are the latency/throughput requirements?" |

Skip clarification only for mechanical conversions where the PRD already contains sufficient technical detail.

## Codebase Exploration

Before drafting, explore the codebase to ground the RFC in reality:

1. **Identify affected modules** — which files/packages will change
2. **Study existing patterns** — how similar features are implemented
3. **Map integration points** — APIs, events, data flows that will be touched
4. **Check constraints** — dependency versions, build system, CI configuration

Reference concrete files and patterns in the RFC to make the design actionable.

## Output Format

Save to `rfc-<feature-name>.md` (project root):

```markdown
# RFC: <Feature Name>

**Date:** <YYYY-MM-DD>
**Status:** Draft
**PRD:** <link or filename of source PRD>

---

## Summary

One paragraph (3-5 sentences) that a busy engineer can read to decide whether the rest of the RFC is relevant to them. Include: what is being proposed, why, and the high-level approach.

---

## Motivation

Why are we doing this? Distill the PRD's problem statement into the technical motivation. What is painful today? What becomes possible after this change?

---

## Detailed Design

### Architecture Overview

Describe the high-level architecture of the proposed solution. Include a diagram if it clarifies relationships between components.

### Component Design

For each major component or module:

#### <Component Name>

- **Responsibility:** What this component does
- **Interface:** Public API, events emitted/consumed, CLI surface
- **Internal behavior:** Key algorithms, state machines, data transformations
- **Dependencies:** What it depends on and why

### Data Model

Schema changes, new entities, or data structure modifications. Include types/interfaces:

```typescript
// Example — use the project's actual language
interface ExampleEntity {
  id: string;
  // ...
}
```

### API Design

For each new or modified endpoint/command/interface:

```
METHOD /path
  Request:  { field: type }
  Response: { field: type }
  Errors:   { code: description }
```

### Error Handling

- How errors propagate through the system
- User-facing error messages and recovery paths
- Retry/fallback strategies

### Migration Strategy

If this changes existing behavior or data:
- How to migrate existing data/state
- Rollback plan
- Feature flags or gradual rollout approach

---

## Alternatives Considered

### <Alternative Name>

- **Approach:** Brief description
- **Pros:** What's good about it
- **Cons:** Why it falls short
- **Verdict:** Why rejected in favor of the proposed design

---

## Trade-offs & Limitations

| Decision | Trade-off | Rationale |
|----------|-----------|-----------|
| Decision 1 | What we give up | Why it's worth it |
| Decision 2 | What we give up | Why it's worth it |

Known limitations of the proposed design that are acceptable for v1.

---

## Security & Privacy

- Authentication/authorization changes
- Data sensitivity classification
- Input validation strategy
- Threat model considerations (if applicable)

---

## Testing Strategy

Derived from the PRD's testing decisions, but made concrete:

| Layer | What to test | Approach |
|-------|-------------|----------|
| Unit | Individual component logic | Isolated tests with mocked dependencies |
| Integration | Component interactions | Tests against real dependencies where feasible |
| E2E | Critical user flows | Automated user-journey tests |

### What NOT to test
- Implementation details that may change
- Third-party library internals

---

## Observability

- Key metrics to track
- Logging strategy (what to log, at what level)
- Alerting thresholds (if applicable)
- Dashboard requirements (if applicable)

---

## Rollout Plan

1. **Phase 1:** Description (e.g., behind feature flag, internal only)
2. **Phase 2:** Description (e.g., canary rollout to N%)
3. **Phase 3:** Description (e.g., general availability)

Rollback trigger: What signals indicate we should roll back?

---

## Open Questions

| # | Question | Impact | Owner |
|---|----------|--------|-------|
| 1 | Question text | What decision it blocks | Who should answer |

---

## References

- Source PRD: `<filename>`
- Related ADRs, RFCs, or design docs
- External specifications or documentation
```

## Conversion Guidelines

### From PRD to RFC — Section Mapping

| PRD Section | RFC Section | Transformation |
|-------------|-------------|----------------|
| Problem Statement | Motivation | Reframe as technical motivation; keep user impact |
| Solution | Summary + Detailed Design | Expand into concrete architecture and component design |
| User Stories | Detailed Design | User stories inform the interfaces and flows |
| Implementation Decisions | Detailed Design | Elevate to formal component design with interfaces |
| Testing Decisions | Testing Strategy | Make concrete: specify layers, tools, and approach |
| Out of Scope | Trade-offs & Limitations | Reframe as deliberate trade-offs with rationale |

### Principles

- **Concrete over abstract** — Reference actual files, types, and patterns from the codebase
- **Critique-ready** — Present decisions as choices with trade-offs, not mandates
- **Reviewable** — A reader should be able to evaluate the design without reading the PRD
- **Self-contained** — The RFC should stand on its own; link to the PRD for context but don't require it
- **Honest about unknowns** — Open Questions section should capture genuine uncertainties, not be empty

### Anti-patterns

- Copying the PRD verbatim into RFC sections — the RFC must add technical depth
- Leaving Detailed Design vague ("we'll figure it out during implementation")
- Omitting Alternatives Considered — every non-trivial design has alternatives
- Empty Security, Observability, or Migration sections without stating "N/A — reason"

## After RFC Creation

Tell the user:

```
RFC saved to rfc-<name>.md

Source PRD: <prd-filename>
Components: <N> components designed
Open Questions: <N> remaining

Review checklist:
- [ ] Architecture handles failure modes
- [ ] Interfaces are minimal and well-defined
- [ ] Data model changes are backward-compatible (or migration planned)
- [ ] Testing strategy covers critical paths
- [ ] Security implications addressed
- [ ] Rollout plan includes rollback trigger

Share with reviewers for feedback.
```