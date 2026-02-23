---
name: rfc-to-issues
description: Break an RFC into independently-grabbable issue files using vertical slices (tracer bullets).
---

# RFC to Issues

Break an RFC into independently-grabbable issue markdown files using vertical slices (tracer bullets).

## Process

### 1. Locate the RFC

Ask the user for the path to the RFC file. Read and internalize the full RFC content. Also locate and read the source PRD referenced in the RFC's frontmatter (the `PRD:` field) to understand the original user stories and acceptance criteria.

### 2. Explore the codebase

Read the key modules and integration layers referenced in the RFC. Identify:

- The distinct integration layers the feature touches (e.g. DB/schema, API/backend, UI, tests, config)
- Existing patterns for similar features
- Natural seams where work can be parallelized

### 3. Draft vertical slices

Break the RFC into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
- The first slice should be the simplest possible end-to-end path (the "hello world" tracer bullet)
- Later slices add breadth: edge cases, additional user stories, polish
</vertical-slice-rules>

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Layers touched**: which integration layers this slice cuts through
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories from the source PRD this addresses

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Is the ordering right for the first tracer bullet?
- Are there any slices missing?

Iterate until the user approves the breakdown.

### 5. Create the issue files

For each approved slice, create a markdown file in the `issues/` directory (relative to the project root). Create the directory if it doesn't exist.

**Filename format:** `YYYY-MM-DD-<issue-slug>.md`

- `YYYY-MM-DD` is the current date
- `<issue-slug>` is a kebab-case slug derived from the issue title

Create files in dependency order (blockers first) so you can reference other issue filenames in the "Blocked by" field.

<issue-template>
# <Issue Title>

## Source RFC

`<rfc-filename>`

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation. Reference specific sections of the source RFC rather than duplicating content.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- `<issue-filename>.md` (if any)

Or "None — can start immediately" if no blockers.

## User stories addressed

Reference by number from the source PRD:

- User story 3
- User story 7
</issue-template>

After creating all issue files, print a summary table:

```
| File | Title | Blocked by | Status |
|------|-------|------------|--------|
| 2026-02-23-basic-widget-creation.md | Basic widget creation | None | Ready |
| 2026-02-23-widget-listing.md | Widget listing | basic-widget-creation | Blocked |
```

Do NOT modify the source RFC or PRD files.